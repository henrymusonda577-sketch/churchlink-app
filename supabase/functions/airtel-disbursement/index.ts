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

// Function to initiate disbursement
async function initiateDisbursement(token: string, reference: string, msisdn: string, amount: number): Promise<any> {
  const response = await fetch(`${airtelBaseUrl}/standard/v1/disbursements/`, {
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
    throw new Error(`Disbursement failed: ${response.statusText}`)
  }

  return await response.json()
}

serve(async (req) => {
  try {
    // Get user from auth
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
    }

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)

    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Invalid token' }), { status: 401 })
    }

    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 })
    }

    const { amount, phoneNumber, description } = await req.json()

    if (!amount || !phoneNumber) {
      return new Response(JSON.stringify({ error: 'Amount and phone number required' }), { status: 400 })
    }

    // Check wallet balance
    const { data: wallet, error: walletError } = await supabase
      .rpc('get_or_create_wallet', { p_user_id: user.id })

    if (walletError) {
      console.error('Wallet error:', walletError)
      return new Response(JSON.stringify({ error: 'Failed to access wallet' }), { status: 500 })
    }

    const { data: balanceData, error: balanceError } = await supabase
      .from('wallets')
      .select('balance')
      .eq('user_id', user.id)
      .single()

    if (balanceError || !balanceData) {
      return new Response(JSON.stringify({ error: 'Wallet not found' }), { status: 404 })
    }

    if (balanceData.balance < amount) {
      return new Response(JSON.stringify({ error: 'Insufficient balance' }), { status: 400 })
    }

    // Get user tier and calculate admin fee
    const { data: userTierData, error: tierError } = await supabase
      .rpc('get_user_tier', { p_user_id: user.id })

    if (tierError) {
      console.error('Tier error:', tierError)
      return new Response(JSON.stringify({ error: 'Failed to get user tier' }), { status: 500 })
    }

    const userTier = userTierData || 'basic'
    const { data: adminFeeData, error: feeError } = await supabase
      .rpc('calculate_admin_fee', { p_amount: amount, p_user_tier: userTier })

    if (feeError) {
      console.error('Fee calculation error:', feeError)
      return new Response(JSON.stringify({ error: 'Failed to calculate fee' }), { status: 500 })
    }

    const adminAmount = adminFeeData || 0
    const recipientAmount = Math.round((amount - adminAmount) * 100) / 100
    const adminPhone = '0973644384' // Admin wallet number

    // Generate references
    const baseRef = `airtel_send_${user.id}_${Date.now()}`
    const recipientRef = `${baseRef}_recipient`
    const adminRef = `${baseRef}_admin`

    // Create transaction records for both transfers
    const transactions = [
      {
        user_id: user.id,
        type: 'send',
        amount: recipientAmount,
        currency: airtelCurrency,
        status: 'pending',
        reference: recipientRef,
        provider: 'airtel',
        description: `${description} (to recipient)`
      },
      {
        user_id: user.id,
        type: 'send',
        amount: adminAmount,
        currency: airtelCurrency,
        status: 'pending',
        reference: adminRef,
        provider: 'airtel',
        description: `${description} (admin fee)`
      }
    ]

    const { data: insertedTransactions, error: txError } = await supabase
      .from('transactions')
      .insert(transactions)
      .select()

    if (txError) {
      console.error('Transaction insert error:', txError)
      return new Response(JSON.stringify({ error: 'Failed to create transactions' }), { status: 500 })
    }

    try {
      // Deduct full amount from wallet
      await supabase.rpc('update_wallet_balance', {
        p_user_id: user.id,
        p_amount: amount,
        p_type: 'send'
      })

      // Get token
      const accessToken = await getAirtelToken()

      // Initiate disbursements
      const recipientResult = await initiateDisbursement(accessToken, recipientRef, phoneNumber, recipientAmount)
      const adminResult = await initiateDisbursement(accessToken, adminRef, adminPhone, adminAmount)

      // Update transactions with external IDs and status
      await supabase
        .from('transactions')
        .update({
          external_id: recipientRef,
          status: 'processing'
        })
        .eq('reference', recipientRef)

      await supabase
        .from('transactions')
        .update({
          external_id: adminRef,
          status: 'processing'
        })
        .eq('reference', adminRef)

      return new Response(JSON.stringify({
        success: true,
        recipientTransactionId: insertedTransactions[0].id,
        adminTransactionId: insertedTransactions[1].id,
        recipientReference: recipientRef,
        adminReference: adminRef,
        status: 'processing'
      }), { status: 200 })

    } catch (apiError) {
      console.error('Airtel API error:', apiError)

      // Refund full amount to wallet
      await supabase.rpc('update_wallet_balance', {
        p_user_id: user.id,
        p_amount: amount,
        p_type: 'receive'
      })

      // Update all transactions to failed
      await supabase
        .from('transactions')
        .update({ status: 'failed' })
        .in('reference', [recipientRef, adminRef])

      return new Response(JSON.stringify({ error: 'Payment initiation failed' }), { status: 500 })
    }

  } catch (error) {
    console.error('Server error:', error)
    return new Response(JSON.stringify({ error: 'Internal server error' }), { status: 500 })
  }
})