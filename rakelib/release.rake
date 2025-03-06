# frozen_string_literal: true

# Used constants:
# - BUILD_DIR

require 'digest'
require 'net/http'
require 'open3'
require 'open-uri'
require 'uri'

def first_match_in_file(file, regexp)
  File.foreach(file) do |line|
    m = regexp.match(line)
    return m if m
  end
end

## [ Release a new version ] ##################################################

namespace :release do
  desc 'Create a new release on GitHub'
  task :new => [:check_versions, :confirm, :github]

  desc 'Check if all versions from the CHANGELOG match'
  task :check_versions do
    results = []

    Utils.table_header('Check', 'Status')

    # Check if bundler is installed first
    results << Utils.table_result(
      Open3.capture3('which', 'bundler')[2].success?,
      'Bundler installed',
      'Please install bundler using `gem install bundler` and run `bundle install` first.'
    )

    # Extract version from Version.swift
    sg_code = File.open('Sources/SwiftGen/Version.swift').grep(/swiftgen = "(.+)"/) { Regexp.last_match(1) }.first
    Utils.table_info('PXSwiftGen Version.swift', sg_code)
    sg_version = sg_code

    # Extract version from Version.swift for SwiftGenKit
    sgk_code = File.open('Sources/SwiftGen/Version.swift').grep(/swiftGenKit = "(.+)"/) { Regexp.last_match(1) }.first
    Utils.table_info('PXSwiftGenKit Version.swift', sgk_code)
    sgk_version = sgk_code

    results << Utils.table_result(
      sg_version == sgk_version,
      'PXSwiftGen & PXSwiftGenKit versions equal',
      'Please ensure PXSwiftGen & PXSwiftGenKit use the same version numbers'
    )

    # Check StencilSwiftKit version too
    lock_version = Utils.spm_resolved_version('StencilSwiftKit')
    results << Utils.table_result(
      !lock_version.nil?,
      "StencilSwiftKit version: #{lock_version}",
      'Please update StencilSwiftKit to latest version in your Package.swift'
    )

    # Check if entry present in CHANGELOG
    changelog_entry = first_match_in_file('CHANGELOG.md', /^## #{Regexp.quote(sg_version)}$/)
    results << Utils.table_result(
      !changelog_entry.nil?,
      'CHANGELOG: Release entry added',
      "Please add an entry for #{sg_version} in CHANGELOG.md"
    )

    changelog_develop = first_match_in_file('CHANGELOG.md', /^## Develop/)
    results << Utils.table_result(
      changelog_develop.nil?,
      'CHANGELOG: No develop entry',
      'Please remove entry for develop in CHANGELOG'
    )

    exit 1 unless results.all?
  end

  task :confirm do
    version = File.open('Sources/SwiftGen/Version.swift').grep(/swiftgen = "(.+)"/) { Regexp.last_match(1) }.first
    print "Release version #{version} [Y/n]? "
    exit 2 unless STDIN.gets.chomp == 'Y'
  end

  desc 'Create a zip containing all the prebuilt binaries'
  task :zip => ['cli:clean'] do
    # Force a universal build
    task('cli:install').invoke(nil, true)
    version = File.open('Sources/SwiftGen/Version.swift').grep(/swiftgen = "(.+)"/) { Regexp.last_match(1) }.first
    `cp LICENCE README.md CHANGELOG.md #{BUILD_DIR}/pxswiftgen`
    `cd #{BUILD_DIR}/pxswiftgen; zip -r ../pxswiftgen-#{version}.zip .`
  end

  desc 'Create a zip containing all the prebuilt binaries in the artifact bundle format (for SwiftPM Package Plugins)'
  task :artifactbundle => :zip do
    bundle_dir = "#{BUILD_DIR}/pxswiftgen.artifactbundle"
    version = File.open('Sources/SwiftGen/Version.swift').grep(/swiftgen = "(.+)"/) { Regexp.last_match(1) }.first

    # Copy the built product to an artifact bundle
    `mkdir -p #{bundle_dir}`
    `cp -Rf #{BUILD_DIR}/pxswiftgen #{bundle_dir}`

    # Write the `info.json` artifact bundle manifest
    info_template = File.read("rakelib/artifactbundle.info.json.template")
    info_file_content = info_template.gsub(/(VERSION)/, version)
    
    File.open("#{bundle_dir}/info.json", "w") do |f|
      f.write(info_file_content)   
    end

    # Zip the bundle
    `cd #{BUILD_DIR}; zip -r pxswiftgen-#{version}.artifactbundle.zip pxswiftgen.artifactbundle/`
  end

  desc "Create a new GitHub release"
  task :github => :artifactbundle do
    require 'octokit'

    client = Utils.octokit_client
    version = File.open('Sources/SwiftGen/Version.swift').grep(/swiftgen = "(.+)"/) { Regexp.last_match(1) }.first
    body = Utils.top_changelog_entry
    artifacts = [
      "pxswiftgen-#{version}.zip",
      "pxswiftgen-#{version}.artifactbundle.zip"
    ]
    repo_name = File.basename(`git remote get-url origin`.chomp, '.git').freeze
    
    # Create (or update) release
    puts "Pushing release notes for tag #{version}"
    begin
      release = client.release_for_tag("pixohq/#{repo_name}", version)
      client.update_release(release.url, tag_name: version, name: version, body: body)
    rescue Octokit::NotFound
      release = client.create_release("pixohq/#{repo_name}", version, name: version, body: body)
    end

    # Upload our artifacts
    artifacts.each do |artifact|
      artifact_path = File.join(BUILD_DIR, artifact)
      client.upload_asset(release.url, artifact_path, name: artifact, content_type: 'application/zip')
    end
  end
end

task :default => 'release:new'
