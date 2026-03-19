# Shared secret references.
#
# This file is loaded on every shell start, but it should only contain
# literal op:// references. Real secret values are resolved only via:
# - secrets-shared-run
# - secrets-shared-load
# - op run
#
# Rules:
# - keep only truly global/shared references here
# - keep project-specific values in the project via .env.1password/.env.local
# - uncomment only what you actually use
# - prefer your shared Development vault naming, for example:
#   export OPENAI_API_KEY="op://Development/OpenAI/api key"

# AI providers
# export OPENAI_API_KEY="op://Development/OpenAI/api key"
# export ANTHROPIC_API_KEY="op://Development/Anthropic/api key"
# export GOOGLE_API_KEY="op://Development/Google/api key"
# export GEMINI_API_KEY="op://Development/Google/api key"
# export MISTRAL_API_KEY="op://Development/Mistral/api key"
# export COHERE_API_KEY="op://Development/Cohere/api key"
# export GROQ_API_KEY="op://Development/Groq/api key"
# export PERPLEXITY_API_KEY="op://Development/Perplexity/api key"
# export TOGETHER_API_KEY="op://Development/Together/api key"
# export XAI_API_KEY="op://Development/xAI/api key"
# export OPENROUTER_API_KEY="op://Development/OpenRouter/api key"
# export DEEPSEEK_API_KEY="op://Development/DeepSeek/api key"

# Git / package registry / containers
# export GITHUB_TOKEN="op://Development/GitHub/personal access token"
# export GH_TOKEN="op://Development/GitHub/personal access token"
# export GITLAB_TOKEN="op://Development/GitLab/personal access token"
# export NPM_TOKEN="op://Development/npm/access token"
# export OS_GHCR_USERNAME="op://Development/GHCR/username"
# export OS_GHCR_TOKEN="op://Development/GHCR/token"

# Cloud / infrastructure
# export CLOUDFLARE_API_TOKEN="op://Development/Cloudflare/api token"
# export AWS_ACCESS_KEY_ID="op://Development/AWS/access key id"
# export AWS_SECRET_ACCESS_KEY="op://Development/AWS/secret access key"
# export AWS_SESSION_TOKEN="op://Development/AWS/session token"
# export FLY_API_TOKEN="op://Development/Fly.io/api token"
# export RAILWAY_TOKEN="op://Development/Railway/token"
# export RENDER_API_KEY="op://Development/Render/api key"
# export VERCEL_TOKEN="op://Development/Vercel/token"
# export NETLIFY_AUTH_TOKEN="op://Development/Netlify/auth token"
# export DIGITALOCEAN_ACCESS_TOKEN="op://Development/DigitalOcean/access token"

# Databases / backend services
# export TURSO_API_TOKEN="op://Development/Turso/api token"
# export SUPABASE_ACCESS_TOKEN="op://Development/Supabase/access token"
# export PLANETSCALE_SERVICE_TOKEN="op://Development/PlanetScale/service token"
# export NEON_API_KEY="op://Development/Neon/api key"
# export UPSTASH_REDIS_REST_TOKEN="op://Development/Upstash/rest token"
# export INNGEST_EVENT_KEY="op://Development/Inngest/event key"
# export INNGEST_SIGNING_KEY="op://Development/Inngest/signing key"

# Search / crawling / retrieval
# export ALGOLIA_API_KEY="op://Development/Algolia/api key"
# export BRAVE_SEARCH_API_KEY="op://Development/Brave Search/api key"
# export EXA_API_KEY="op://Development/Exa/api key"
# export FIRECRAWL_API_KEY="op://Development/Firecrawl/api key"
# export SERPAPI_API_KEY="op://Development/SerpAPI/api key"
# export TAVILY_API_KEY="op://Development/Tavily/api key"

# Observability / product tooling
# export LINEAR_API_KEY="op://Development/Linear/api key"
# export RESEND_API_KEY="op://Development/Resend/api key"
# export POSTMARK_SERVER_TOKEN="op://Development/Postmark/server token"
# export SENDGRID_API_KEY="op://Development/SendGrid/api key"
# export SENTRY_AUTH_TOKEN="op://Development/Sentry/auth token"
# export SLACK_BOT_TOKEN="op://Development/Slack/bot token"
# export DISCORD_BOT_TOKEN="op://Development/Discord/bot token"

# Media / speech / transcription
# export ASSEMBLYAI_API_KEY="op://Development/AssemblyAI/api key"
# export DEEPGRAM_API_KEY="op://Development/Deepgram/api key"
# export ELEVENLABS_API_KEY="op://Development/ElevenLabs/api key"

# Personal global services
# export MOODLE_USERNAME="op://Development/Moodle/username"
# export MOODLE_PASSWORD="op://Development/Moodle/password"
# export OS_STUDY_USERNAME="op://Development/Study/username"
# export OS_STUDY_PASSWORD="op://Development/Study/password"
# export STUDY_SYNC_CALENDAR_URL="op://Development/Study/calendar url"

# Example custom service naming
# export EXAMPLE_SERVICE_API_KEY="op://Development/Example Service/api key"
