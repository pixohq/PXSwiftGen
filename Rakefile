#!/usr/bin/rake
# frozen_string_literal: true

require 'pathname'
require 'yaml'
require 'shellwords'

if ENV['BUNDLE_GEMFILE'].nil?
  puts "\u{274C} Please use bundle exec"
  exit 1
end

## [ Constants ] ##############################################################

MIN_XCODE_VERSION = 13.0
BUILD_DIR = File.absolute_path('./.build')

## [ Build Tasks ] ############################################################

namespace :cli do
  desc "바이너리 빌드\n" \
    "(in #{BUILD_DIR})"
  task :build, %[universal] do |task, args|
    args.with_defaults(universal: false)

    Utils.print_header '바이너리 빌드 중'
    archs = args.universal ? '--arch arm64 --arch x86_64' : ''
    Utils.run(%(swift build --disable-sandbox -c release #{archs}), task, xcrun: true, formatter: :raw)
  end

  desc "바이너리를 $bindir에 설치\n" \
       "(기본값 $bindir=#{BUILD_DIR}/pxswiftgen/bin/)"
  task :install, %i[bindir universal] => :build do |task, args|
    args.with_defaults(bindir: "#{BUILD_DIR}/pxswiftgen/bin/", universal: false)

    bindir = Pathname.new(args.bindir).expand_path
    actual_build_dir = args.universal ? "#{BUILD_DIR}/apple/Products/Release" : "#{BUILD_DIR}/release"
    generated_binary_path = "#{actual_build_dir}/pxswiftgen"
    generated_bundle_path = "#{actual_build_dir}/PXSwiftGen_SwiftGenCLI.bundle"

    Utils.print_header "바이너리 설치 중: #{bindir}"
    Utils.run([
                %(mkdir -p "#{bindir}"),
                %(cp -f "#{generated_binary_path}" "#{bindir}/pxswiftgen"),
                %(cp -Rf "#{generated_bundle_path}" "#{bindir}/PXSwiftGen_SwiftGenCLI.bundle")
              ], task, 'copy_binary')

    Utils.print_info "설치 완료. 바이너리 위치: #{bindir}"
  end

  desc "빌드 디렉토리 삭제\n" \
    "(#{BUILD_DIR})"
  task :clean do
    sh %(rm -fr #{BUILD_DIR}/pxswiftgen)
  end

  desc "바이너리 테스트 실행\n" \
       "(기본값 $bindir=#{BUILD_DIR}/pxswiftgen/bin/)"
  task :test, %i[bindir universal] => :install do |task, args|
    args.with_defaults(bindir: "#{BUILD_DIR}/pxswiftgen/bin/", universal: false)
    swiftgen = Pathname.new(args.bindir).expand_path + "pxswiftgen"

    tests = {
      colors:   {template: 'swift5',            resource_group: 'Colors',   generated: 'defaults.swift',    fixture: 'colors.xml'},
      coredata: {template: 'swift5',            resource_group: 'CoreData', generated: 'defaults.swift',    fixture: 'Model.xcdatamodeld'},
      files:    {template: 'structured-swift5', resource_group: 'Files',    generated: 'defaults.swift',    fixture: ''},
      fonts:    {template: 'swift5',            resource_group: 'Fonts',    generated: 'defaults.swift',    fixture: ''},
      ib:       {template: 'scenes-swift5',     resource_group: 'IB-iOS',   generated: 'all.swift',         fixture: '', params: '--param module=SwiftGen'},
      json:     {template: 'runtime-swift5',    resource_group: 'JSON',     generated: 'all.swift',         fixture: ''},
      plist:    {template: 'runtime-swift5',    resource_group: 'Plist',    generated: 'all.swift',         fixture: 'good'},
      strings:  {template: 'structured-swift5', resource_group: 'Strings',  generated: 'localizable.swift', fixture: 'Localizable.strings'},
      xcassets: {template: 'swift5',            resource_group: 'XCAssets', generated: 'all.swift',         fixture: ''},
      yaml:     {template: 'inline-swift5',     resource_group: 'YAML',     generated: 'all.swift',         fixture: 'good'}
    }

    results = []
    Utils.table_header('Check', 'Status')

    tests.each do |command, info|
      output = %x(#{swiftgen.to_s} run #{command} --templateName #{info[:template]} #{info[:params]} Sources/TestUtils/Fixtures/Resources/#{info[:resource_group]}/#{info[:fixture]}).strip
      generated = File.read("Sources/TestUtils/Fixtures/Generated/#{info[:resource_group]}/#{info[:template]}/#{info[:generated]}").strip
      results << Utils.table_result(
        output == generated,
        command.to_s,
        %Q(pxswiftgen run #{command} --templateName #{info[:template]} #{info[:params]} Sources/TestUtils/Fixtures/Resources/#{info[:resource_group]}/#{info[:fixture]})
      )
    end

    exit 1 unless results.all?
  end
end

task :default => 'cli:build'
