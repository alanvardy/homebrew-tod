require "digest"
require "open-uri"

version = ARGV[0] or abort("Usage: ruby update_formula.rb <version> (e.g. 0.8.0)")
tag = "v#{version}"
base_url = "https://github.com/alanvardy/tod/releases/download/#{tag}"

platforms = {
  mac_arm:     "tod-#{version}-darwin-arm64.tar.gz",
  mac_intel:   "tod-#{version}-darwin-amd64.tar.gz",
  linux_arm:   "tod-#{version}-linux-arm64.tar.gz",
  linux_intel: "tod-#{version}-linux-amd64.tar.gz"
}

sha256s = {}

# Download and compute SHA256s
platforms.each do |key, filename|
  url = "#{base_url}/#{filename}"
  puts "🔽 Downloading #{url}..."
  file = URI.open(url).read
  sha256s[key] = Digest::SHA256.hexdigest(file)
end

formula_path = "Formula/tod.rb"
formula = File.read(formula_path)

# Update version string
formula.gsub!(/version\s+"[^"]+"/, "version \"#{version}\"")

# Helper to replace URL and SHA within a platform-specific block
def replace_platform_block(formula, platform_key, filename, new_sha)
  platform_section = case platform_key
  when :mac_arm     then [/on_macos.*?on_arm.*?\n(.*?)url\s+"[^"]+"\n\s+sha256\s+"[a-f0-9]+"/m, "macOS ARM"]
  when :mac_intel   then [/on_macos.*?on_intel.*?\n(.*?)url\s+"[^"]+"\n\s+sha256\s+"[a-f0-9]+"/m, "macOS Intel"]
  when :linux_arm   then [/on_linux.*?on_arm.*?\n(.*?)url\s+"[^"]+"\n\s+sha256\s+"[a-f0-9]+"/m, "Linux ARM"]
  when :linux_intel then [/on_linux.*?on_intel.*?\n(.*?)url\s+"[^"]+"\n\s+sha256\s+"[a-f0-9]+"/m, "Linux Intel"]
  end

  pattern, label = platform_section
  new_url = "url \"https://github.com/alanvardy/tod/releases/download/v#{ARGV[0]}/#{filename}\""
  new_sha_line = "sha256 \"#{new_sha}\""

  updated = formula.sub(pattern) do |block|
    block.gsub(/url\s+"[^"]+"/, new_url).gsub(/sha256\s+"[a-f0-9]+"/, new_sha_line)
  end

  if updated == formula
    puts "⚠️  Could not find or replace block for #{label}"
  else
    puts "✅ Updated #{label} block"
    formula.replace(updated)
  end
end

# Replace each platform-specific block
platforms.each do |key, filename|
  replace_platform_block(formula, key, filename, sha256s[key])
end

# Save changes
File.write(formula_path, formula)
puts "✅ Updated #{formula_path} for v#{version}"
