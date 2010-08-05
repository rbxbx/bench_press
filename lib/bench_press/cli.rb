module BenchPress
  require 'optparse'
  class CLI
    attr_reader :argv, :options, :filename

    def initialize(argv)
      @argv = argv
      @options = {}
      optparse.parse!(argv)
      @filename = argv.shift
    end

    def email
      options[:email] || git_email
    end

    def file_path
      @file_path ||= File.join(Dir.pwd, filename)
    end

    def file_exists?
      filename && File.exists?(file_path)
    end

    def git_email
      @git_email ||= %x(git config --global --get user.email).strip
    end

    def optparse
      @optparse ||= OptionParser.new do |opts|
        opts.banner = "Usage: bench_press [options] file_to_benchmark.rb"

        opts.on( '-n', '--new', 'Create a new benchmark' ) do
          options[:new] = true
        end

        opts.on( '-p', '--publish', 'Publish the benchmark to http://rubybenchmark.com' ) do
          options[:publish] = true
        end

        opts.on('--email EMAIL', String, "Author email, defaults to #{git_email}") do |email|
          options[:email] = email
        end

        opts.on( '-v', '--version', 'Show the version of bench_press' ) do
          options[:version] = true
        end
      end
    end

    def run
      if options[:version]
        exit_with_version
      elsif file_exists?
        perform_bench_press
      elsif options[:new]
        new_bench_press
      else
        abort "Could not proceed, please supply the filename you wish to benchmark"
      end
    end

    protected

    def perform_bench_press
      measurable.bench_press
      if options[:publish]
        publish
      else
        puts measurable.report
      end
    end

    def measurable
      @measurable ||= begin
        $0 = File.basename(file_path)
        load file_path
        BenchPress.run_at_exit = false
        BenchPress.current
      end
    end

    def exit_with_version
      puts BenchPress::VERSION
      exit
    end

    def publish
      if email && email.any?
        measurable.email email
        puts measurable.report; puts
        puts RubyBenchmark.publish(measurable, file_path)
      else
        abort "Email missing. Use bench_press --publish --email me@example.com file.rb"
      end
    end

    def new_bench_press
      if filename && File.exists?(file_path_with_rb)
        abort "A file named #{filename} already exists"
      else
        File.open(file_path_with_rb, 'w') { |f| f.write(template) } unless file_exists?
      end
    end

    def file_path_with_rb
      file_path + '.rb'
    end

    def template
      <<-TEMPLATE

require 'bench_press'

extend BenchPress

name 'gem1 vs. gem2'
author 'YOUR NAME'
date '#{Time.now.strftime('%Y-%m-%d')}'
summary "
  Describe what you're benchmarking
"

reps 10_000 #number of repetitions

measure "Class#method" do
  # code to be benchmarked
end

      TEMPLATE
    end

  end
end
