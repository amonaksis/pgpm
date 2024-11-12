# frozen_string_literal: true

module Pgpm
  module RPM
    module Mock
      class Operation
        def self.buildsrpm(spec, sources, config: nil, result_dir: nil, cb: nil)
          buffer_result_dir = Dir.mktmpdir("pgpm")
          args = [
            "--buildsrpm", "--spec", spec, "--resultdir",
            buffer_result_dir
          ]
          args.push("--sources", sources) if sources
          args.push("-r", config.to_s) unless config.nil?
          new(*args, cb: lambda {
            rpms = Dir.glob("*.rpm", base: buffer_result_dir).map do |f|
              FileUtils.cp(Pathname(buffer_result_dir).join(f), result_dir) unless result_dir.nil?
              f
            end
            FileUtils.rm_rf(buffer_result_dir)
            cb.call unless cb.nil?
            rpms
          })
        end

        def self.rebuild(srpm, config: nil, result_dir: nil, cb: nil)
          buffer_result_dir = Dir.mktmpdir("pgpm")
          args = [
            "--rebuild", "--chain", "--recurse", srpm, "--localrepo", buffer_result_dir
          ]
          args.push("-r", config.to_s) unless config.nil?
          new(*args, cb: lambda {
            # Here we glob for **/*.rpm as ``--localrepo` behaves differently from
            # `--resultdir`
            rpms = Dir.glob("**/*.rpm", base: buffer_result_dir).map do |f|
              FileUtils.cp(Pathname(buffer_result_dir).join(f), result_dir) unless result_dir.nil?
              f
            end
            FileUtils.rm_rf(buffer_result_dir)
            cb.call unless cb.nil?
            rpms
          })
        end

        def initialize(*args, opts: nil, cb: nil)
          @args = args
          @cb = cb
          @opts = opts || { "print_main_output" => "True", "pgdg_version" => Postgres::Distribution.in_scope.major_version }
        end

        attr_reader :args, :cb

        def call
          options = @opts.flat_map { |(k, v)| ["--config-opts", "#{k}=#{v}"] }.compact.join(" ")
          command = "mock #{options} #{@args.join(" ")}"
          raise "Failed to execute `#{command}`" unless system command

          @cb&.call
        end

        def chain(op)
          raise ArgumentError, "can't chain non-rebuild operations" unless op.args.include?("--rebuild") && @args.include?("--rebuild")

          args = @args.clone
          args.insert(@args.index("--localrepo") - 1, op.args[op.args.index("--localrepo") - 1])
          self.class.new(*args, cb: lambda {
            res1 = @cb&.call
            res2 = op.cb&.call
            return res1 + res2 if res1.is_a?(Array) && res2.is_a?(Array)

            res2
          })
        end

        def and_then(op)
          lambda do
            res1 = call
            res2 = op.call
            return res1 + res2 if res1.is_a?(Array) && res2.is_a?(Array)

            [res1, res2]
          end
        end
      end
    end
  end
end
