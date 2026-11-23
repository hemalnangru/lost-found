import nodemailer from "nodemailer";

const user = process.env.GMAIL_USER;
const pass = process.env.GMAIL_APP_PASSWORD?.replace(/\s/g, "");

if (!user || !pass) {
  console.error("Set GMAIL_USER and GMAIL_APP_PASSWORD in .env.local first.");
  process.exit(1);
}

const transporter = nodemailer.createTransport({
  host: "smtp.gmail.com",
  port: 465,
  secure: true,
  auth: { user, pass },
});

try {
  await transporter.sendMail({
    from: `Pan-India Lost & Found <${user}>`,
    to: user,
    subject: "Test email from Pan-India Lost & Found",
    text: "If you can read this, email alerts are set up correctly.",
  });
  console.log(`Sent. Check the inbox of ${user} (and the spam folder).`);
} catch (e) {
  console.error("Failed:", e.message);
  if (/self.signed|certificate/i.test(e.message)) {
    console.error("Your network is intercepting secure connections. Try your phone hotspot.");
  }
  if (/Invalid login|Username and Password|535/i.test(e.message)) {
    console.error("Use a Gmail app password (16 letters), not your normal password.");
  }
  process.exit(1);
}
