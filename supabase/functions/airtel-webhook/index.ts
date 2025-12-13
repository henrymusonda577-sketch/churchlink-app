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
    console.log('Airtel webhook received:', webhookData)

    // Airtel webhook structure: typically { transaction: { id, status, ... }, subscriber: {...} }
    const transactionId = webhookData.transaction?.id || webhookData.id
    const status = webhookData.transaction?.status || webhookData.status

    if (!transactionId || !status) {
      console.error('Invalid webhook data')
      return new Response(JSON.stringify({ error: 'Invalid data' }), { status: 400 })
    }

    // Find transaction by external_id or reference
    const { data: transaction, error: findError } = await supabase
      .from('transactions')
      .select('*')
      .or(`external_id.eq.${transactionId},reference.eq.${transactionId}`)
      .eq('provider', 'airtel')
      .single()

    if (findError || !transaction) {
      console.error('Transaction not found:', transactionId)
      return new Response(JSON.stringify({ error: 'Transaction not found' }), { status: 404 })
    }

    // Map Airtel status to our status
    let newStatus = 'processing'
    if (status === 'SUCCESS' || status === 'SUCCESSFUL') {
      newStatus = 'completed'
    } else if (status === 'FAILED' || status === 'FAILURE') {
      newStatus = 'failed'
    } else if (status === 'PENDING') {
      newStatus = 'processing'
    }

    // Update transaction status
    const { error: updateError } = await supabase
      .from('transactions')
      .update({
        status: newStatus,
        updated_at: new Date().toISOString()
      })
      .eq('id', transaction.id)

    if (updateError) {
      console.error('Update error:', updateError)
      return new Response(JSON.stringify({ error: 'Update failed' }), { status: 500 })
    }

    // Only update wallet for non-donation and non-admin-fee transactions
    const isDonation = transaction.description?.startsWith('Donation:') ?? false;
    const isAdminFee = transaction.description?.includes('(admin fee)') ?? false;

    if (!isDonation && !isAdminFee) {
      // If completed and receive type, update wallet balance
      if (newStatus === 'completed' && transaction.type === 'receive') {
        await supabase.rpc('update_wallet_balance', {
          p_user_id: transaction.user_id,
          p_amount: transaction.amount,
          p_type: 'receive'
        })
      }

      // If failed and send type, refund wallet
      if (newStatus === 'failed' && transaction.type === 'send') {
        await supabase.rpc('update_wallet_balance', {
          p_user_id: transaction.user_id,
          p_amount: transaction.amount,
          p_type: 'receive'
        })
      }
    }

    // Update donation status if it's a donation
    if (isDonation && transaction.external_id) {
      await supabase
        .from('donations')
        .update({ status: newStatus })
        .eq('transaction_id', transaction.external_id)
    }

    return new Response(JSON.stringify({ success: true }), { status: 200 })

  } catch (error) {
    console.error('Webhook error:', error)
    return new Response(JSON.stringify({ error: 'Internal server error' }), { status: 500 })
  }
})