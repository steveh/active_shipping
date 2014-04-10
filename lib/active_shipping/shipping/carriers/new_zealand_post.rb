module ActiveMerchant
  module Shipping
    class NewZealandPost < Carrier

      cattr_reader :name
      @@name = 'New Zealand Post'

      URL = 'http://shippingoptions-nzpg.au.cloudhub.io/v1'

      def requirements
        [:account_number, :license_key]
      end

      def find_rates(origin, destination, packages, options = {})
        options = @options.merge(options)
        request = RateRequest.from(origin, destination, packages, options)
        request.raw_responses = commit(request.urls) if request.new_zealand_origin?
        request.rate_response
      end

    protected

      def commit(urls)
        save_request(urls).map do |url|
          ssl_get(url, headers)
        end
      end

      def headers
        {
          "license-key" => @options[:license_key],
        }
      end

      def self.default_location
        Location.new({
          :country => 'NZ',
          :city => 'Wellington',
          :address1 => '22 Waterloo Quay',
          :address2 => 'Pipitea',
          :postal_code => '6011'
        })
      end

      class NewZealandPostRateResponse < RateResponse

        attr_reader :raw_responses

        def initialize(success, message, params = {}, options = {})
          @raw_responses = options[:raw_responses]
          super
        end
      end

      class RateRequest

        attr_reader :urls
        attr_writer :raw_responses

        def self.from(*args)
          return International.new(*args) unless domestic?(args[0..1])
          Domestic.new(*args)
        end

        def initialize(origin, destination, packages, options)
          @origin = Location.from(origin)
          @destination = Location.from(destination)
          @packages = Array(packages).map { |package| NewZealandPostPackage.new(package, api) }
          @params = { "account_number" => options[:account_number] }
          @test = options[:test]
          @rates = @responses = @raw_responses = []
          @urls = @packages.map { |package| url(package) }
        end

        def rate_response
          @rates = rates
          NewZealandPostRateResponse.new(true, 'success', response_params, response_options)
        rescue => error
          NewZealandPostRateResponse.new(false, error.message, response_params, response_options)
        end

        def new_zealand_origin?
          self.class.new_zealand?(@origin)
        end

        def service_name(product)
          product['name']
        end

        def price(product)
          product['price_inc_gst'].to_f
        end

      protected

        def self.new_zealand?(location)
          [ 'NZ', nil ].include?(Location.from(location).country_code)
        end

        def self.domestic?(locations)
          locations.select { |location| new_zealand?(location) }.size == 2
        end

        def response_options
          {
            :rates => @rates,
            :raw_responses => @raw_responses,
            :request => @urls,
            :test => @test
          }
        end

        def response_params
          { :responses => @responses }
        end

        def rates
          rates_hash.map do |service, products|
            RateEstimate.new(@origin, @destination, NewZealandPost.name, service, rate_options(products))
          end
        end

        def rate_options(products)
          {
            :total_price => products.sum { |product| price(product) },
            :currency => 'NZD',
            :service_code => products.first['code']
          }
        end

        def rates_hash
          products_hash.select { |service, products| products.size == @packages.size }
        end

        def products_hash
          product_arrays.flatten.group_by { |product| service_name(product) }
        end

        def product_arrays
          responses.map do |response|
            raise response['message'].to_s unless response['success']
            response['services']
          end
        end

        def responses
          @responses = @raw_responses.map { |response| parse_response(response) }
        end

        def parse_response(response)
          JSON.parse(response)
        end

        def url(package)
          "#{URL}/#{api}?#{params(package).to_query}"
        end

        def params(package)
          @params.merge(api_params).merge(package.params)
        end

      end

      class Domestic < RateRequest
        def api
          :domestic
        end

        def api_params
          {
            "pickup_address_post_code" => @origin.postal_code,
            "pickup_address_suburb" => @origin.address2,
            "delivery_address_post_code" => @destination.postal_code,
            "delivery_address_suburb" => @destination.address2,
          }
        end
      end

      class International < RateRequest

        def rates
          raise 'New Zealand Post packages must originate in New Zealand' unless new_zealand_origin?
          super
        end

        def api
          :international
        end

        def api_params
          { "delivery_country" => @destination.country_code }
        end
      end

      class NewZealandPostPackage

        def initialize(package, api)
          @package = package
          @api = api
          @params = { "weight" => weight }
        end

        def params
          @params.merge(api_params).merge(shape_params)
        end

        protected

        def weight
          # API rounds up weights to nearest kg
          [@package.kg.ceil, 1].max
        end

        def length
          [cm(:length).ceil, 1].max
        end

        def height
          [cm(:height).ceil, 1].max
        end

        def width
          [cm(:width).ceil, 1].max
        end

        def diameter
          [cm(:diameter).ceil, 1].max
        end

        def shape
          return :cylinder if @package.cylinder?
          :cuboid
        end

        def api_params
          send("#{@api}_params")
        end

        def international_params
          { "value" => value }
        end

        def domestic_params
          {}
        end

        def shape_params
          send("#{shape}_params")
        end

        def cuboid_params
          { "width" => width, "height" => height, "length" => length }
        end

        def cylinder_params
          { "diameter" => width, "length" => length }
        end

        def cm(measurement)
          @package.cm(measurement)
        end

        def value
          return 0 unless @package.value && currency == 'NZD'
          @package.value / 100
        end

        def currency
          @package.currency || 'NZD'
        end

      end
    end
  end
end
