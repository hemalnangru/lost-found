import nodemailer from "nodemailer";

type Mail = { to: string; subject: string; text: string; html: string };

// Sends through Gmail with an app password. Returns false when the
// credentials are not configured, so the rest of the app keeps working.
export async function sendMail({ to, subject, text, html }: Mail): Promise<boolean> {
  const user = process.env.GMAIL_USER;
  const pass = process.env.GMAIL_APP_PASSWORD?.replace(/\s/g, "");
  if (!user || !pass) {
    console.warn("[mail] GMAIL_USER or GMAIL_APP_PASSWORD is not set. Skipping email.");
    return false;
  }

  const transporter = nodemailer.createTransport({
    host: "smtp.gmail.com",
    port: 465,
    secure: true,
    auth: { user, pass },
  });

  await transporter.sendMail({
    from: `Pan-India Lost & Found <${user}>`,
    to,
    subject,
    text,
    html,
  });
  return true;
}
