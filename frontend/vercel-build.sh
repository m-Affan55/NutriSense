#!/bin/bash

# 1. Create the .env file from Vercel Environment Variables
echo "SUPABASE_URL=$SUPABASE_URL" > .env
echo "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" >> .env
echo ".env file generated successfully."

# 2. Clone Flutter SDK (Stable Channel)
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:`pwd`/flutter/bin"

# 3. Build Flutter Web Release
flutter doctor
flutter build web --release
