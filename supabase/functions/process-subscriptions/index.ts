import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const supabase = createClient(supabaseUrl, supabaseServiceKey)

const airtelClientId = Deno.env.get('AIRTEL_CLIENT_ID')!
const airtelClientSecret = Deno.env.get('AIRTEL_CLIENT_SECRET')!
const airtelBaseUrl = Deno.env.get('AIRTEL_BASE_URL')!
const airtelCountry = Deno.env.get('AIRTEL_COUNTRY')!
const airtelCurrency = Deno.env.get('AIRTEL_CURRENCY')!

const mtnApiKey = Deno.env.get('MTN_API_KEY')!
const mtnSubscriptionKey = Deno.env.get('MTN_SUBSCRIPTION_KEY')!
const mtnBaseUrl = Deno.env.get('MTN_BASE_URL')!
const mtnCurrency = Deno.env.get('MTN_CURRENCY')!

// Function to get Airtel access token
async function getAirtelToken(): Promise<string> {
  const auth = btoa(`${airtelClientId}:${airtelClientSecret}`)
  const response = await fetch(`${airtelBaseUrl}/auth/oauth2/token`, {
    method: 'POST',
    headers: {
      'Authorization': `Basic ${auth}`,
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: 'grant_type=client_credentials'
  })

  if (!response.ok) {
    throw new Error(`Failed to get token: ${response.statusText}`)
  }

  const data = await response.json()
  return data.access_token
}

// Function to initiate Airtel collection for subscription
async function initiateAirtelCollection(token: string, reference: string, msisdn: string, amount: number): Promise<any> {
  const response = await fetch(`${airtelBaseUrl}/merchant/v1/payments/`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      reference,
      subscriber: {
        country: airtelCountry,
        currency: airtelCurrency,
        msisdn
      },
      transaction: {
        amount,
        country: airtelCountry,
        currency: airtelCurrency,
        id: reference
      }
    })
  })

  if (!response.ok) {
    throw new Error(`Collection failed: ${response.statusText}`)
  }

  return await response.json()
}

// Function to get MTN auth header
function getMtnAuth(): string {
  return `Basic ${btoa(`${mtnApiKey}:`)}`
}

// Function to initiate MTN collection for subscription
async function initiateMtnCollection(reference: string, msisdn: string, amount: number): Promise<any> {
  const response = await fetch(`${mtnBaseUrl}/collection/v1_0/requesttopay`, {
    method: 'POST',
    headers: {
      'Authorization': getMtnAuth(),
      'Ocp-Apim-Subscription-Key': mtnSubscriptionKey,
      'Content-Type': 'application/json',
      'X-Reference-Id': reference
    },
    body: JSON.stringify({
      amount: amount.toString(),
      currency: mtnCurrency,
      externalId: reference,
      payer: {
        partyIdType: "MSISDN",
        partyId: msisdn
      },
      payerMessage: "Monthly subscription payment",
      payeeNote: "Subscription fee"
    })
  })

  if (!response.ok) {
    const errorText = await response.text()
    throw new Error(`Collection failed: ${response.status} ${errorText}`)
  }

  return await response.json()
}

serve(async (req) => {
  try {
    // Only allow POST requests
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 })
    }

    console.log('Processing subscriptions...')

    // Get all active subscriptions due for payment
    const now = new Date()
    const { data: dueSubscriptions, error: subError } = await supabase
      .from('subscriptions')
      .select(`
        *,
        user:user_id (
          phone,
          wallet_tier
        )
      `)
      .eq('status', 'active')
      .lte('next_payment_date', now.toISOString())

    if (subError) {
      console.error('Error fetching subscriptions:', subError)
      return new Response(JSON.stringify({ error: 'Failed to fetch subscriptions' }), { status: 500 })
    }

    console.log(`Found ${dueSubscriptions?.length || 0} subscriptions due for payment`)

    const results = []

    for (const subscription of dueSubscriptions || []) {
      try {
        const user = subscription.user
        if (!user?.phone) {
          console.error(`No phone number for user ${subscription.user_id}`)
          continue
        }

        const phoneNumber = user.phone.replace(/^\+/, '')
        const reference = `sub_${subscription.user_id}_${Date.now()}`

        // Create subscription payment record
        const { data: payment, error: paymentError } = await supabase
          .from('subscription_payments')
          .insert({
            subscription_id: subscription.id,
            user_id: subscription.user_id,
            amount: subscription.amount,
            currency: subscription.currency,
            payment_method: subscription.payment_method,
            reference
          })
          .select()
          .single()

        if (paymentError) {
          console.error('Error creating payment record:', paymentError)
          continue
        }

        try {
          let result
          if (subscription.payment_method === 'airtel') {
            const token = await getAirtelToken()
            result = await initiateAirtelCollection(token, reference, phoneNumber, subscription.amount)
          } else if (subscription.payment_method === 'mtn') {
            result = await initiateMtnCollection(reference, phoneNumber, subscription.amount)
          } else {
            throw new Error(`Unsupported payment method: ${subscription.payment_method}`)
          }

          // Update payment status to processing
          await supabase
            .from('subscription_payments')
            .update({
              status: 'processing',
              transaction_id: result.transaction?.id || result.id || reference
            })
            .eq('id', payment.id)

          results.push({
            subscription_id: subscription.id,
            status: 'processing',
            reference
          })

        } catch (apiError) {
          console.error(`API error for subscription ${subscription.id}:`, apiError)

          // Mark payment as failed
          await supabase
            .from('subscription_payments')
            .update({ status: 'failed' })
            .eq('id', payment.id)

          // Downgrade user to basic
          await supabase.rpc('update_user_tier', {
            p_user_id: subscription.user_id,
            p_new_tier: 'basic',
            p_reason: 'payment_failed'
          })

          // Update subscription status
          await supabase
            .from('subscriptions')
            .update({ status: 'expired' })
            .eq('id', subscription.id)

          results.push({
            subscription_id: subscription.id,
            status: 'failed_downgraded',
            error: apiError.message
          })
        }

      } catch (error) {
        console.error(`Error processing subscription ${subscription.id}:`, error)
        results.push({
          subscription_id: subscription.id,
          status: 'error',
          error: error.message
        })
      }
    }

    return new Response(JSON.stringify({
      success: true,
      processed: results.length,
      results
    }), { status: 200 })

  } catch (error) {
    console.error('Server error:', error)
    return new Response(JSON.stringify({ error: 'Internal server error' }), { status: 500 })
  }
})