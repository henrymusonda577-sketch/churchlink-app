import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import nodemailer from 'npm:nodemailer'

interface ReportData {
  id: string
  post_id: string
  reported_by: string
  reason: string
  created_at: string
}

Deno.serve(async (req) => {
  try {
    // Get the report data from the request
    const { record }: { record: ReportData } = await req.json()

    // Initialize Supabase client
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Get post details
    const { data: post, error: postError } = await supabase
      .from('posts')
      .select('content, user_id')
      .eq('id', record.post_id)
      .single()

    if (postError) {
      console.error('Error fetching post:', postError)
      return new Response(JSON.stringify({ error: 'Failed to fetch post' }), { status: 500 })
    }

    // Get reporter details
    const { data: reporter, error: reporterError } = await supabase.auth.admin.getUserById(record.reported_by)

    if (reporterError) {
      console.error('Error fetching reporter:', reporterError)
      return new Response(JSON.stringify({ error: 'Failed to fetch reporter' }), { status: 500 })
    }

    // Get post author details
    const { data: author, error: authorError } = await supabase.auth.admin.getUserById(post.user_id)

    if (authorError) {
      console.error('Error fetching author:', authorError)
      return new Response(JSON.stringify({ error: 'Failed to fetch author' }), { status: 500 })
    }

    // Set up email transporter
    const transporter = nodemailer.createTransporter({
      host: Deno.env.get('SMTP_HOST') ?? 'smtp.mailgun.org',
      port: 587,
      secure: false,
      auth: {
        user: Deno.env.get('SMTP_USER') ?? '',
        pass: Deno.env.get('SMTP_PASS') ?? ''
      }
    })

    // Email content
    const mailOptions = {
      from: Deno.env.get('SMTP_FROM') ?? 'noreply@yourapp.com',
      to: 'henrymusonda577@gmail.com',
      subject: 'New Post Report - Action Required',
      html: `
        <h2>New Post Report</h2>
        <p><strong>Post ID:</strong> ${record.post_id}</p>
        <p><strong>Reported by:</strong> ${reporter.user?.email ?? 'Unknown'}</p>
        <p><strong>Post Author:</strong> ${author.user?.email ?? 'Unknown'}</p>
        <p><strong>Reason:</strong> ${record.reason}</p>
        <p><strong>Post Content:</strong></p>
        <blockquote>${post.content}</blockquote>
        <p><strong>Reported at:</strong> ${new Date(record.created_at).toLocaleString()}</p>
        <p>Please review this report and take appropriate action.</p>
      `
    }

    // Send email
    const info = await transporter.sendMail(mailOptions)
    console.log('Email sent:', info.messageId)

    return new Response(JSON.stringify({ success: true }), { status: 200 })

  } catch (error) {
    console.error('Error sending report email:', error)
    return new Response(JSON.stringify({ error: 'Internal server error' }), { status: 500 })
  }
})