const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const publicDir = path.join(root, "public");

const files = [
  "index.html",
  "script.js",
  "afterschool.js",
  "afterschoolScheduleData.js",
  "style.css",
  "flex.html",
  "flex.css",
  "flex.js",
  "schedule.js",
  "privacy.html",
  "privacy-theme.js",
  "sw.js",
  "firebase-messaging-sw.js",
  "notification.js",
  "manifest.json",
  "app-update.json",
  "logo.svg",
  "icon-192.png",
  "icon1.png",
  "favicon.png",
  "apple-touch-icon.png",
];

function copyFile(relativePath, destinationDir) {
  const source = path.join(root, relativePath);
  const destination = path.join(destinationDir, path.basename(relativePath));
  fs.copyFileSync(source, destination);
}

fs.mkdirSync(publicDir, { recursive: true });
fs.mkdirSync(path.join(publicDir, ".well-known"), { recursive: true });
fs.mkdirSync(path.join(publicDir, "src"), { recursive: true });

for (const file of files) {
  copyFile(file, publicDir);
}

fs.rmSync(path.join(publicDir, "src", "data"), { recursive: true, force: true });
fs.cpSync(path.join(root, "src", "data"), path.join(publicDir, "src", "data"), {
  recursive: true,
});

copyFile(path.join(".well-known", "assetlinks.json"), path.join(publicDir, ".well-known"));

console.log("Hosting assets copied to public/");
