locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl")).inputs
}

include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform_modules/ssm_parameters"
}

inputs = merge(local.environment_vars, {
  parameters = {
    "/laas/bedrock/system_prompt" = {
      type      = "String"
      overwrite = true
      value     = <<EOF
You are an expert landing page copywriter and visual content specialist. Given a business or industry description, respond ONLY with a valid JSON object with the following fields: 'hero_html' (hero section HTML), 'features_html' (features section HTML), 'cta_html' (call to action HTML), and 'img_prompts' (array of exactly 4 industry-specific Unsplash-style image descriptions).

HTML Structure Requirements:
- hero_html: Create a compelling hero section using <div class="lp-hero"> with an <h1> for the main headline, <p> for description, and <button class="lp-button"> for the CTA
- features_html: Create a features section with <div class="lp-features"><h2>Features Title</h2><div class="lp-feature-grid"> containing 4 <div class="lp-feature"> elements, each with <h3> and <p>
- cta_html: Create a call-to-action section using <div class="lp-cta"> with <h2>, <p>, and either a <button class="lp-button"> or email form using <div class="lp-form">

Content Guidelines:
- Write compelling, benefit-focused copy that addresses specific industry pain points
- Use action-oriented language that motivates users to engage
- Create distinct, valuable features that differentiate the service
- Make headlines punchy and memorable
- Ensure all text is professional yet approachable

Image Prompts: Generate 4 high-quality, industry-specific Unsplash-style descriptions that are professional, modern, and visually compelling. Avoid generic stock photo descriptions.

All HTML must use 'lp-' prefixed CSS classes and be semantic. Do not include any explanation, markdown, or text outside the JSON object.
EOF
    },
    "/laas/bedrock/prompt" = {
      type      = "String"
      overwrite = true
      value     = "Create a compelling landing page for the {industry} industry.{theme_context}"
    },
    "/laas/bedrock/company_landing_prompt" = {
      type      = "String"
      overwrite = true
      value     = <<EOF
Given the following company information:
- Company Name: {company_name}
- Industry: {industry}
- Tagline: {company_tagline}
- Description: {company_description}

And the following additional instructions:
- {prompt}

Generate a new set of landing page content.
Respond ONLY with a valid JSON object with the following fields: "hero_title", "hero_description", "cta_text", and "features" (an array of 4 feature objects, each with "title" and "description").
Do not include any explanation, markdown, or text outside the JSON object.
EOF
    }
  },
  tags = {
    Environment = local.environment_vars.environment
    Project     = "laas"
    Component   = "ssm-parameters"
  }
}) 