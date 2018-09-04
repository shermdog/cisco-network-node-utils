# Copyright (c) 2015-2018 Cisco and/or its affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'ipaddr'
require_relative 'node_util'

module Cisco
  # Ace - node utility class for Ace Configuration
  class Ace < NodeUtil
    attr_reader :afi, :acl_name

    def initialize(afi, acl_name, seqno)
      @afi = Acl.afi_cli(afi)
      @acl_name = acl_name.to_s
      @seqno = seqno.to_s
      set_args_keys_default
    end

    # Create a hash of all aces under a given acl_name.
    def self.aces
      afis = %w(ipv4 ipv6)
      hash = {}
      afis.each do |afi|
        hash[afi] = {}
        acls = config_get('acl', 'all_acls', afi: Acl.afi_cli(afi))
        next if acls.nil?

        acls.each do |acl_name|
          hash[afi][acl_name] = {}
          aces = config_get('acl', 'all_aces',
                            afi: Acl.afi_cli(afi), acl_name: acl_name)
          next if aces.nil?

          aces.each do |seqno|
            hash[afi][acl_name][seqno] = Ace.new(afi, acl_name, seqno)
          end
        end
      end
      hash
    end

    def destroy
      set_args_keys(state: 'no')
      config_set('acl', 'ace_destroy', @set_args)
    end

    def set_args_keys_default
      keys = { afi: @afi, acl_name: @acl_name, seqno: @seqno }
      @get_args = @set_args = keys
    end

    # rubocop:disable Style/AccessorMethodName
    def set_args_keys(hash={})
      set_args_keys_default
      @set_args = @get_args.merge!(hash) unless hash.empty?
    end

    # common ace getter
    def ace_get
      str = config_get('acl', 'ace', @get_args)
      return nil if str.nil?

      remark = Regexp.new('(?<seqno>\d+) remark (?<remark>.*)').match(str)
      return remark unless remark.nil?

      # rubocop:disable Metrics/LineLength
      regexp = Regexp.new('(?<seqno>\d+) (?<action>\S+)'\
                 ' *(?<proto>\d+|\S+)'\
                 ' *(?<src_addr>any|host \S+|[:\.0-9a-fA-F]+ [:\.0-9a-fA-F]+|[:\.0-9a-fA-F]+\/\d+|addrgroup \S+)'\
                 ' *(?<src_port>range \S+ \S+|(lt|eq|gt|neq|portgroup) \S+)?'\
                 ' *(?<dst_addr>any|host \S+|[:\.0-9a-fA-F]+ [:\.0-9a-fA-F]+|[:\.0-9a-fA-F]+\/\d+|addrgroup \S+)'\
                 ' *(?<dst_port>range \S+ \S+|(lt|eq|gt|neq|portgroup) \S+)?'\
                 ' *(?<tcp_flags>(ack *|fin *|urg *|syn *|psh *|rst *)*)?'\
                 ' *(?<established>established)?'\
                 ' *(?<precedence>precedence \S+)?'\
                 ' *(?<dscp>dscp \S+)?'\
                 ' *(?<time_range>time-range \S+)?'\
                 ' *(?<packet_length>packet-length (range \d+ \d+|(lt|eq|gt|neq) \d+))?'\
                 ' *(?<ttl>ttl \d+)?'\
                 ' *(?<http_method>http-method (\d+|connect|delete|get|head|post|put|trace))?'\
                 ' *(?<tcp_option_length>tcp-option-length \d+)?'\
                 ' *(?<redirect>redirect \S+)?'\
                 ' *(?<log>log)?')
      # rubocop:enable Metrics/LineLength
      regexp.match(str)
    end

    def icmp_get
      str = config_get('acl', 'ace', @get_args)
      return nil if str.nil?

      remark = Regexp.new('(?<seqno>\d+) remark (?<remark>.*)').match(str)
      return remark unless remark.nil?

      # rubocop:disable Metrics/LineLength
      regexp = Regexp.new('(?<seqno>\d+) (?<action>\S+)'\
                 ' *(?<proto>\d+|\S+)'\
                 ' *(?<src_addr>any|host \S+|[:\.0-9a-fA-F]+ [:\.0-9a-fA-F]+|[:\.0-9a-fA-F]+\/\d+|addrgroup \S+)'\
                 ' *(?<dst_addr>any|host \S+|[:\.0-9a-fA-F]+ [:\.0-9a-fA-F]+|[:\.0-9a-fA-F]+\/\d+|addrgroup \S+)'\
                 ' *(?<precedence>precedence \S+)?'\
                 ' *(?<icmp_type>\S+)?'\
                 ' *(?<dscp>dscp \S+)?'\
                 ' *(?<time_range>time-range \S+)?'\
                 ' *(?<packet_length>packet-length (range \d+ \d+|(lt|eq|gt|neq) \d+))?'\
                 ' *(?<ttl>ttl \d+)?'\
                 ' *(?<redirect>redirect \S+)?'\
                 ' *(?<log>log)?')
      # rubocop:enable Metrics/LineLength
      regexp.match(str)
    end

    # common ace setter. Put the values you need in a hash and pass it in.
    # attrs = {:action=>'permit', :proto=>'tcp', :src =>'host 1.1.1.1'}
    def ace_set(attrs)
      if attrs.empty?
        attrs[:state] = 'no'
      else
        # remove existing ace first
        destroy if seqno
        attrs[:state] = ''
      end

      if attrs[:remark]
        cmd = 'ace_remark'
        set_args_keys(attrs)
      else
        cmd = 'ace'
        set_args_keys_default
        set_args_keys(attrs)
        [:action,
         :proto,
         :src_addr,
         :src_port,
         :dst_addr,
         :dst_port,
         :tcp_flags,
         :established,
         :precedence,
         :dscp,
         :time_range,
         :packet_length,
         :ttl,
         :http_method,
         :tcp_option_length,
         :redirect,
         :log,
        ].each do |p|
          attrs[p] = '' if attrs[p].nil?
          send(p.to_s + '=', attrs[p])
        end
        @get_args = @set_args
      end
      config_set('acl', cmd, @set_args)
    end

    def valid_ipv6?(addr)
      begin
        ret = IPAddr.new(addr.split[0]).ipv6?
      rescue
        ret = false
      end
      ret
    end

    # PROPERTIES
    # ----------
    def seqno
      match = ace_get
      return nil if match.nil?
      match.names.include?('seqno') ? match[:seqno] : nil
    end

    def action
      match = ace_get
      return nil if match.nil?
      match.names.include?('action') ? match[:action] : nil
    end

    def action=(action)
      @set_args[:action] = action
    end

    def remark
      match = ace_get
      return nil if match.nil?
      match.names.include?('remark') ? match[:remark] : nil
    end

    def remark=(remark)
      @set_args[:remark] = remark
    end

    def proto
      match = ace_get
      return nil if match.nil?
      match.names.include?('proto') ? match[:proto] : nil
    end

    def proto=(proto)
      @set_args[:proto] = proto # TBD ip vs ipv4
    end

    def src_addr
      match = ace_get
      return nil if match.nil? || !match.names.include?('src_addr')
      addr = match[:src_addr]
      # Normalize addr. Some platforms zero_pad ipv6 addrs.
      addr.gsub!(/^0*/, '').gsub!(/:0*/, ':') if valid_ipv6?(addr)
      addr
    end

    def src_addr=(src_addr)
      @set_args[:src_addr] = src_addr
    end

    def src_port
      match = ace_get
      return nil if match.nil?
      match.names.include?('src_port') ? match[:src_port] : nil
    end

    def src_port=(src_port)
      @set_args[:src_port] = src_port
    end

    def dst_addr
      match = ace_get
      return nil if match.nil? || !match.names.include?('dst_addr')
      addr = match[:dst_addr]
      # Normalize addr. Some platforms zero_pad ipv6 addrs.
      addr.gsub!(/^0*/, '').gsub!(/:0*/, ':') if valid_ipv6?(addr)
      addr
    end

    def dst_addr=(dst_addr)
      @set_args[:dst_addr] = dst_addr
    end

    def dst_port
      match = ace_get
      return nil if match.nil?
      match.names.include?('dst_port') ? match[:dst_port] : nil
    end

    def dst_port=(src_port)
      @set_args[:dst_port] = src_port
    end

    def tcp_flags
      match = ace_get
      return nil if match.nil?
      match.names.include?('tcp_flags') ? match[:tcp_flags].strip : nil
    end

    def tcp_flags=(tcp_flags)
      @set_args[:tcp_flags] = tcp_flags.strip
    end

    def established
      match = ace_get
      return nil unless remark.nil?
      return false if match.nil?
      return false unless match.names.include?('established')
      match[:established] == 'established' ? true : false
    end

    def established=(established)
      @set_args[:established] = established.to_s == 'true' ? 'established' : ''
    end

    def precedence
      Utils.extract_value(ace_get, 'precedence')
    end

    def precedence=(precedence)
      @set_args[:precedence] = Utils.attach_prefix(precedence, :precedence)
    end

    def dscp
      Utils.extract_value(ace_get, 'dscp')
    end

    def dscp=(dscp)
      @set_args[:dscp] = Utils.attach_prefix(dscp, :dscp)
    end

    def time_range
      Utils.extract_value(ace_get, 'time_range', 'time-range')
    end

    def time_range=(time_range)
      @set_args[:time_range] = Utils.attach_prefix(time_range,
                                                   :time_range,
                                                   'time-range')
    end

    def packet_length
      Utils.extract_value(ace_get, 'packet_length', 'packet-length')
    end

    def packet_length=(packet_length)
      @set_args[:packet_length] = Utils.attach_prefix(packet_length,
                                                      :packet_length,
                                                      'packet-length')
    end

    def ttl
      Utils.extract_value(ace_get, 'ttl')
    end

    def ttl=(ttl)
      @set_args[:ttl] = Utils.attach_prefix(ttl, :ttl)
    end

    def http_method
      Utils.extract_value(ace_get, 'http_method', 'http-method')
    end

    def http_method=(http_method)
      @set_args[:http_method] = Utils.attach_prefix(http_method,
                                                    :http_method,
                                                    'http-method')
    end

    def tcp_option_length
      Utils.extract_value(ace_get, 'tcp_option_length', 'tcp-option-length')
    end

    def tcp_option_length=(tcp_option_length)
      @set_args[:tcp_option_length] = Utils.attach_prefix(tcp_option_length,
                                                          :tcp_option_length,
                                                          'tcp-option-length')
    end

    def redirect
      Utils.extract_value(ace_get, 'redirect')
    end

    def redirect=(redirect)
      @set_args[:redirect] = Utils.attach_prefix(redirect, :redirect)
    end

    def log
      match = ace_get
      return nil unless remark.nil?
      return false if match.nil?
      return false unless match.names.include?('log')
      match[:log] == 'log' ? true : false
    end

    def log=(log)
      @set_args[:log] = log.to_s == 'true' ? 'log' : ''
    end

    def icmp_message
      match = ace_get
      return nil unless match[:proto] == 'icmp'
      icmp_get[:icmp_type]
      # return nil if match.nil? || !match.names.include?('dst_addr')
      # addr = match[:dst_addr]
      # # Normalize addr. Some platforms zero_pad ipv6 addrs.
      # addr.gsub!(/^0*/, '').gsub!(/:0*/, ':') if valid_ipv6?(addr)
      # addr
    end
  end
end
