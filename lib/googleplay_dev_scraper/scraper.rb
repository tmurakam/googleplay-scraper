#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# = GooglePlay Scraper
# Author:: Takuya Murakami
# License:: Public domain

require 'mechanize'
require 'csv'
require 'yaml'
require 'date'

module GooglePlayDevScraper
  #
  # Google Play and google checkout scraper
  #
  class Scraper < ScraperBase

    def initialize
      super
    end

    def body_string
      @agent.page.body.force_encoding("UTF-8")
    end

    # Get sales report (report_type = payout_report)
    # [year]
    #   Year (ex. 2012)
    # [month]
    #   Month (1 - 12)
    # [Return]
    #   CSV string
    #
    def get_sales_report(year, month)
      #url = sprintf('https://play.google.com/apps/publish/salesreport/download?report_date=%04d_%02d&report_type=payout_report&dev_acc=%s', year, month, @config.dev_acc)
      url = sprintf('https://play.google.com/apps/publish/v2/salesreport/download?report_date=%04d_%02d&report_type=payout_report&dev_acc=%s', year, month, @config.dev_acc)
      try_get(url)

      body_string
    end

    # Get estimated sales report (report_type = sales_report)
    #
    # [year]
    #   Year (ex. 2012)
    # [month]
    #   Month (1 - 12)
    # [Return]
    #   CSV string
    #
    def get_estimated_sales_report(year, month)
      #https://play.google.com/apps/publish/v2/salesreport/download?report_date=2013_03&report_type=sales_report&dev_acc=09924472108471074593
      #url = sprintf('https://play.google.com/apps/publish/v2/salesreport/download?report_date=%04d_%02d&report_type=sales_report&dev_acc=%s', year, month, @config.dev_acc)
      url = sprintf('https://storage.cloud.google.com/pubsite_prod_rev_%s/sales/salesreport_%04d%02d.zip', @config.dev_acc, year, month)
      try_get(url)

      body_string
    end

    # Get order list
    #
    # [start_date]
    #   start time (DateTime)
    # [end_date]
    #   end time (DateTime)
    # [Return]
    #   CSV string
    def get_order_list(start_time, end_time)
      # unix time in ms
      start_ut = start_time.to_time.to_i * 1000
      end_ut = end_time.to_time.to_i * 1000

      try_get("https://wallet.google.com/merchant/pages/")
      if @agent.page.uri.path =~ /(bcid-[^\/]+)\/(oid-[^\/]+)\/(cid-[^\/]+)\//
        bcid = $1
        oid = $2
        cid = $3

        # You can check the URL with your browser.
        # (download csv file, and check download history with chrome/firefox)
        try_get("https://wallet.google.com/merchant/pages/" +
                bcid + "/" + oid + "/" + cid +
                "/purchaseorderdownload?startTime=#{start_ut}" + 
                "&endTime=#{end_ut}")
        body_string
      end
    end

    # Get application statistics CSV in zip
    #
    # [package]
    #   package name
    # [start_day]
    #   start date (yyyyMMdd)
    # [end_day]
    #   end date (yyyyMMdd)
    # [Return]
    #   application statics zip data
    #
    def get_appstats(package, start_day, end_day)
      #dim = "overall,country,language,os_version,device,app_version,carrier&met=active_device_installs,daily_device_installs,daily_device_uninstalls,daily_device_upgrades,active_user_installs,total_user_installs,daily_user_installs,daily_user_uninstalls,daily_avg_rating,total_avg_rating"
      #url = "https://play.google.com/apps/publish/v2/statistics/download"

      # 2013/8/7 changed?
      dim = "overall,os_version,device,country,language,app_version,carrier,crash_details,anr_details&met=current_device_installs,daily_device_installs,daily_device_uninstalls,daily_device_upgrades,current_user_installs,total_user_installs,daily_user_installs,daily_user_uninstalls,daily_avg_rating,total_avg_rating,daily_crashes,daily_anrs"
      url = "https://play.google.com/apps/publish/statistics/download"
      url += "?package=#{package}"
      url += "&sd=#{start_day}&ed=#{end_day}"
      url += "&dim=#{dim}"
      #url += "&dev_acc=#{@config.dev_acc}"

      STDERR.puts "URL = #{url}"
      try_get(url)
      @agent.page.body
    end

    # dump CSV (util)
    def dump_csv(csv_string)
      headers = nil
      CSV.parse(csv_string) do |row|
        unless headers
          headers = row
          next
        end

        i = 0
        row.each do |column|
          puts "#{headers[i]} : #{column}"
          i = i + 1
        end
        puts
      end
    end

    #
    # Get order list from wallet html page
    #
    def get_wallet_orders
      try_get("https://wallet.google.com/merchant/pages/")
      html = body_string

      doc = Nokogiri::HTML(html)

      #doc.xpath("//table[@id='purchaseOrderListTable']")

      result = ""

      doc.xpath("//tr[@class='orderRow']").each do |e|
        order_id = e['id']

        date = nil
        desc = nil
        total = nil
        status = nil

        e.children.each do |e2|
          case e2['class']
          when /wallet-date-column/
            date = e2.content
          when /wallet-description-column/
            desc = e2.content
          when /wallet-total-column/
            total = e2.content
          when /wallet-status-column/
            e3 = e2.children.first
            status = e3['title'] unless e3.nil?
          end
        end

        result += [order_id, date, desc, status, total].join(",") + "\n"
      end

      result
    end
  end
end
