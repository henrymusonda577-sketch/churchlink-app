import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

console.log('Environment check:', {
  supabaseUrl: supabaseUrl ? 'present' : 'missing',
  supabaseServiceKey: supabaseServiceKey ? 'present' : 'missing'
})

const supabase = createClient(supabaseUrl, supabaseServiceKey)

const mtnApiKey = Deno.env.get('MTN_API_KEY')!
const mtnSubscriptionKey = Deno.env.get('MTN_SUBSCRIPTION_KEY')!
const mtnBaseUrl = Deno.env.get('MTN_BASE_URL')!
const mtnCurrency = Deno.env.get('MTN_CURRENCY')!

// Function to get MTN auth header
function getMtnAuth(): string {
  return `Basic ${btoa(`${mtnApiKey}:`)}`
}

// Function to initiate collection
async function initiateCollection(reference: string, msisdn: string, amount: number): Promise<any> {
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
      payerMessage: "Payment request",
      payeeNote: "Mobile money payment"
    })
  })

  if (!response.ok) {
    const errorText = await response.text()
    throw new Error(`Collection failed: ${response.status} ${errorText}`)
  }

  return await response.json()
}

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get user from auth
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const token = authHeader.replace('Bearer ', '')
    console.log('Authenticating user with token...')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)

    if (authError || !user) {
      console.error('Authentication failed:', { authError, user: user ? 'exists' : 'null' })
      return new Response(JSON.stringify({ error: 'Invalid token' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    console.log('User authenticated:', { userId: user.id, email: user.email })

    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const { amount, phoneNumber, description } = await req.json()

    if (!amount || !phoneNumber) {
      return new Response(JSON.stringify({ error: 'Amount and phone number required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Generate reference
    const reference = `mtn_recv_${user.id}_${Date.now()}`

    // Create transaction record
    console.log('Creating transaction with data:', {
      user_id: user.id,
      type: 'receive',
      amount,
      currency: mtnCurrency,
      status: 'pending',
      reference,
      provider: 'mtn',
      description
    })

    const { data: transaction, error: txError } = await supabase
      .from('transactions')
      .insert({
        user_id: user.id,
        type: 'receive',
        amount,
        currency: mtnCurrency,
        status: 'pending',
        reference,
        provider: 'mtn',
        description
      })
      .select()
      .single()

    if (txError) {
      console.error('Transaction insert error:', txError)
      console.error('Transaction insert error details:', {
        code: txError.code,
        details: txError.details,
        hint: txError.hint,
        message: txError.message
      })
      return new Response(JSON.stringify({
        error: 'Failed to create transaction',
        details: txError.message,
        code: txError.code
      }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    console.log('Transaction created successfully:', transaction)

    try {
      // Initiate collection
      const result = await initiateCollection(reference, phoneNumber, amount)

      // Update transaction with external ID
      await supabase
        .from('transactions')
        .update({
          external_id: reference, // MTN uses X-Reference-Id as external ID
          status: 'processing'
        })
        .eq('id', transaction.id)

      return new Response(JSON.stringify({
        success: true,
        transactionId: transaction.id,
        reference,
        status: 'processing'
      }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })

    } catch (apiError) {
      console.error('MTN API error:', apiError)

      // Update transaction status to failed
      await supabase
        .from('transactions')
        .update({ status: 'failed' })
        .eq('id', transaction.id)

      return new Response(JSON.stringify({ error: 'Payment initiation failed' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

  } catch (error) {
    console.error('Server error:', error)
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})