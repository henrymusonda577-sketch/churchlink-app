import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const supabase = createClient(supabaseUrl, supabaseServiceKey)

serve(async (req) => {
  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 })
    }

    const webhookData = await req.json()
    console.log('Subscription webhook received:', webhookData)

    // Handle both Airtel and MTN webhook formats
    let referenceId: string
    let status: string

    if (webhookData.referenceId) {
      // MTN format
      referenceId = webhookData.referenceId
      status = webhookData.status
    } else if (webhookData.transaction?.id) {
      // Airtel format
      referenceId = webhookData.transaction.id
      status = webhookData.transaction.status || webhookData.status
    } else {
      console.error('Invalid webhook data format')
      return new Response(JSON.stringify({ error: 'Invalid data format' }), { status: 400 })
    }

    if (!referenceId || !status) {
      console.error('Missing reference or status')
      return new Response(JSON.stringify({ error: 'Invalid data' }), { status: 400 })
    }

    // Find subscription payment by reference
    const { data: payment, error: findError } = await supabase
      .from('subscription_payments')
      .select(`
        *,
        subscription:subscription_id (
          user_id,
          tier,
          amount
        )
      `)
      .eq('reference', referenceId)
      .single()

    if (findError || !payment) {
      console.error('Subscription payment not found:', referenceId)
      return new Response(JSON.stringify({ error: 'Payment not found' }), { status: 404 })
    }

    // Map status to our format
    let newStatus = 'processing'
    if (status === 'SUCCESSFUL' || status === 'SUCCESS') {
      newStatus = 'completed'
    } else if (status === 'FAILED' || status === 'FAILURE') {
      newStatus = 'failed'
    }

    // Update payment status
    const { error: updateError } = await supabase
      .from('subscription_payments')
      .update({
        status: newStatus,
        payment_date: new Date().toISOString()
      })
      .eq('id', payment.id)

    if (updateError) {
      console.error('Update error:', updateError)
      return new Response(JSON.stringify({ error: 'Update failed' }), { status: 500 })
    }

    // If payment completed, update subscription next payment date
    if (newStatus === 'completed') {
      const nextPayment = new Date()
      nextPayment.setMonth(nextPayment.getMonth() + 1)

      await supabase
        .from('subscriptions')
        .update({
          last_payment_date: new Date().toISOString(),
          next_payment_date: nextPayment.toISOString(),
          updated_at: new Date().toISOString()
        })
        .eq('id', payment.subscription_id)

    } else if (newStatus === 'failed') {
      // If payment failed, downgrade user and expire subscription
      await supabase.rpc('update_user_tier', {
        p_user_id: payment.subscription.user_id,
        p_new_tier: 'basic',
        p_reason: 'payment_failed'
      })

      await supabase
        .from('subscriptions')
        .update({ status: 'expired' })
        .eq('id', payment.subscription_id)

      // TODO: Send notification to user
      console.log(`User ${payment.subscription.user_id} downgraded due to failed payment`)
    }

    return new Response(JSON.stringify({ success: true }), { status: 200 })

  } catch (error) {
    console.error('Webhook error:', error)
    return new Response(JSON.stringify({ error: 'Internal server error' }), { status: 500 })
  }
})