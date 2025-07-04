# Puppeteer Lambda Module

This module deploys a Node.js Lambda function that uses Puppeteer to render dynamic websites and return the fully rendered HTML.

## Build & Deploy Instructions

1. Place your Node.js Lambda code (index.js, package.json) in `build/`.
2. Run `npm install` in the `build/` directory to install dependencies.
3. Zip the contents of `build/` (including `node_modules`) as `lambda-puppeteer.zip`:
   
   ```bash
   cd build
   npm install
   zip -r lambda-puppeteer.zip index.js package.json node_modules/
   ```
4. Place `lambda-puppeteer.zip` in this module's `build/` directory.
5. Run `terragrunt apply` in the appropriate environment directory to deploy.

## Handler
- Handler: `index.handler`
- Runtime: `nodejs18.x`

## Environment Variables
- Add any required environment variables to `main.tf` as needed. 