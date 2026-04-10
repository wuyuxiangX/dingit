import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createMDX } from 'fumadocs-mdx/next';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const withMDX = createMDX();

/** @type {import('next').NextConfig} */
const config = {
  reactStrictMode: true,
  // Explicitly anchor the workspace root to this app. Without this Next
  // walks up the filesystem and finds a stray package-lock.json in a parent
  // directory, which triggers a "Multiple lockfiles detected" warning.
  turbopack: {
    root: path.join(__dirname, '..', '..'),
  },
};

export default withMDX(config);
