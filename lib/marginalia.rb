require 'marginalia/railtie'
require 'marginalia/comment'

module Marginalia
  mattr_accessor :application_name

  module ActiveRecordInstrumentation
    def self.included(instrumented_class)
      Marginalia::Comment.components = [:application, :controller, :action]
      instrumented_class.class_eval do
        if instrumented_class.method_defined?(:execute)
          alias_method :execute_without_marginalia, :execute
          alias_method :execute, :execute_with_marginalia
        end

        is_mysql2 = defined?(ActiveRecord::ConnectionAdapters::Mysql2Adapter) &&
          ActiveRecord::ConnectionAdapters::Mysql2Adapter == instrumented_class
        # Dont instrument exec_query on mysql2 and AR 3.2+, as it calls execute internally
        unless is_mysql2 && ActiveRecord::VERSION::STRING > "3.1"
          if instrumented_class.method_defined?(:exec_query)
            alias_method :exec_query_without_marginalia, :exec_query
            alias_method :exec_query, :exec_query_with_marginalia
          end
        end
      end
    end

    def annotate_sql(sql)
      comment = Marginalia::Comment.construct_comment
      if comment.present? && !sql.include?(comment)
        "#{sql} /*#{comment}*/"
      else
        sql
      end
    end

    def execute_with_marginalia(sql, name = nil)
      execute_without_marginalia(annotate_sql(sql), name)
    end

    def exec_query_with_marginalia(sql, name = 'SQL', binds = [])
      exec_query_without_marginalia(annotate_sql(sql), name, binds)
    end
  end

end
