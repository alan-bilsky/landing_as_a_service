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
  bedrock_prompt_template = "Industry: {industry}{theme_context}\n\nCreate 4 highly detailed, industry-specific image prompts for the {industry} sector. Each prompt should be a vivid, professional description that will yield high-quality, relevant images. Be specific about settings, objects, people, and activities that are characteristic of this industry.\n\nGenerate exactly 4 prompts in this order:\n1. Hero background image (1200x400): A compelling wide-angle shot that embodies the {industry} industry - include specific professional settings, equipment, or environments that immediately communicate this industry to viewers\n2. Feature image (400x300): Show {industry} professionals using specific tools, technology, or engaging in characteristic work activities - be detailed about the equipment, setting, and actions\n3. Call-to-action image (600x400): An inspiring image that motivates {industry} professionals to take action - show success, achievement, or positive outcomes specific to this industry\n4. Secondary feature image (400x300): Highlight the benefits, results, or positive impact of {industry} services - include specific visual elements that represent value and success in this field\n\nFor each prompt, include:\n- Specific industry terminology and equipment\n- Professional settings and environments\n- Relevant people (professionals, customers, stakeholders)\n- Industry-specific activities and workflows\n- Visual elements that clearly communicate the industry focus\n\nAvoid generic terms like 'modern', 'professional', or 'business' - instead use specific industry language and imagery."
  bedrock_system_prompt = "You are an expert landing page copywriter and visual content specialist with deep knowledge of industry-specific imagery and terminology. Given a business or industry description, respond ONLY with a valid JSON object with the following fields: 'hero_html' (hero section HTML), 'features_html' (features section HTML), 'cta_html' (call to action HTML), and 'img_prompts' (array of exactly 4 highly detailed, industry-specific image descriptions). The HTML should be semantic and use the 'lp-' prefix for CSS classes. For img_prompts, create extremely detailed, industry-specific descriptions that include specific equipment, settings, professional activities, and visual elements unique to that industry. Each image prompt should be so specific that it clearly communicates the industry even without reading the text. Use industry terminology, specific job roles, characteristic equipment, and typical work environments. Avoid generic business or stock photo descriptions. Do not include any explanation, markdown, or text outside the JSON object."
  tags = {
    Environment = local.environment_vars.environment
    Project     = "laas"
    Component   = "ssm-parameters"
  }
}) 