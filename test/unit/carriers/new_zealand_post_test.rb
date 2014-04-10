require "test_helper"

class NewZealandPostTest < Test::Unit::TestCase

  def setup
    @carrier  = NewZealandPost.new(fixtures(:new_zealand_post).merge(:test => true))
    @packages  = TestFixtures.packages
    @locations = TestFixtures.locations
    @wellington = @locations[:wellington]
    @auckland = @locations[:auckland]
    @ottawa = @locations[:ottawa]
  end

  def test_domestic_book_request
    url = "http://shippingoptions-nzpg.au.cloudhub.io/v1/domestic?account_number=91833337&delivery_address_post_code=1010&delivery_address_suburb=Auckland&height=2&length=19&pickup_address_post_code=6011&pickup_address_suburb=Te+Aro&weight=1&width=14"
    @carrier.expects(:commit).with([ url ]).returns([ json_fixture("newzealandpost/domestic_book") ])
    @carrier.find_rates(@wellington, @auckland, @packages[:book])
  end

  def test_domestic_poster_request
    url = "http://shippingoptions-nzpg.au.cloudhub.io/v1/domestic?account_number=91833337&delivery_address_post_code=1010&delivery_address_suburb=Auckland&diameter=10&length=93&pickup_address_post_code=6011&pickup_address_suburb=Te+Aro&weight=1"
    @carrier.expects(:commit).with([ url ]).returns([ json_fixture("newzealandpost/domestic_poster") ])
    @carrier.find_rates(@wellington, @auckland, @packages[:poster])
  end

  def test_domestic_combined_request
    urls = [
      "http://shippingoptions-nzpg.au.cloudhub.io/v1/domestic?account_number=91833337&delivery_address_post_code=1010&delivery_address_suburb=Auckland&height=2&length=19&pickup_address_post_code=6011&pickup_address_suburb=Te+Aro&weight=1&width=14",
      "http://shippingoptions-nzpg.au.cloudhub.io/v1/domestic?account_number=91833337&delivery_address_post_code=1010&delivery_address_suburb=Auckland&height=3&length=3&pickup_address_post_code=6011&pickup_address_suburb=Te+Aro&weight=1&width=3"
    ]
    @carrier.expects(:commit).with(urls).returns([ json_fixture("newzealandpost/domestic_book"), json_fixture("newzealandpost/domestic_small_half_pound") ])
    @carrier.find_rates(@wellington, @auckland, @packages.values_at(:book, :small_half_pound))
  end

  def test_domestic_book_response
    @carrier.expects(:commit).returns([ json_fixture("newzealandpost/domestic_book") ])
    response = @carrier.find_rates(@wellington, @auckland, @packages[:book])
    assert_equal 1, response.rates.size
    assert_equal [ 958 ], response.rates.map(&:price)
  end

  def test_domestic_poster_response
    @carrier.expects(:commit).returns([ json_fixture("newzealandpost/domestic_poster") ])
    response = @carrier.find_rates(@wellington, @auckland, @packages[:poster])
    assert_equal 1, response.rates.size
    assert_equal [ 958 ], response.rates.map(&:price)
  end

  def test_domestic_combined_response_parsing
    @carrier.expects(:commit).returns([ json_fixture("newzealandpost/domestic_book"), json_fixture("newzealandpost/domestic_small_half_pound") ])
    response = @carrier.find_rates(@wellington, @auckland, @packages.values_at(:book, :small_half_pound))
    assert_equal 1, response.rates.size
    assert_equal [ 1916 ], response.rates.map(&:price)
    assert_equal [ "CPOLP" ], response.rates.map(&:service_code)
    names = [
      "CP Online Parcel"
    ]
    assert_equal names, response.rates.map(&:service_name)
  end

  def test_domestic_shipping_container_response_error
    skip "api incomplete"

    url ="http://shippingoptions-nzpg.au.cloudhub.io/v1/domestic?account_number=91833337&delivery_address_post_code=1010&delivery_address_suburb=Auckland&height=2440&length=6058&pickup_address_post_code=6011&pickup_address_suburb=Te+Aro&weight=2200&width=2600"
    @carrier.expects(:commit).with([url]).returns([ json_fixture("newzealandpost/domestic_error") ])
    error = @carrier.find_rates(@wellington, @auckland, @packages[:shipping_container]) rescue $!
    assert_equal ActiveMerchant::Shipping::ResponseError, error.class
    assert_equal "Weight can only be between 0 and 25kg", error.message
    assert_equal [ json_fixture("newzealandpost/domestic_error") ], error.response.raw_responses
    response_params = { "responses" => [ JSON.parse(json_fixture("newzealandpost/domestic_error")) ] }
    assert_equal response_params, error.response.params
  end

  def test_domestic_blank_package_response
    url = "http://shippingoptions-nzpg.au.cloudhub.io/v1/domestic?account_number=91833337&delivery_address_post_code=1010&delivery_address_suburb=Auckland&height=1&length=1&pickup_address_post_code=6011&pickup_address_suburb=Te+Aro&weight=1&width=1"
    @carrier.expects(:commit).with([ url ]).returns([ json_fixture("newzealandpost/domestic_default") ])
    response = @carrier.find_rates(@wellington, @auckland, @packages[:just_zero_grams])
    assert_equal [ 958 ], response.rates.map(&:price)
  end

  def test_domestic_book_response_params
    url = "http://shippingoptions-nzpg.au.cloudhub.io/v1/domestic?account_number=91833337&delivery_address_post_code=1010&delivery_address_suburb=Auckland&height=2&length=19&pickup_address_post_code=6011&pickup_address_suburb=Te+Aro&weight=1&width=14"
    @carrier.expects(:commit).with([ url ]).returns([ json_fixture("newzealandpost/domestic_book") ])
    response = @carrier.find_rates(@wellington, @auckland, @packages[:book])
    assert_equal [ url ], response.request
    assert_equal [ json_fixture("newzealandpost/domestic_book") ], response.raw_responses
    assert_equal [ JSON.parse(json_fixture("newzealandpost/domestic_book")) ], response.params["responses"]
  end

  def test_international_book_request
    url = "http://shippingoptions-nzpg.au.cloudhub.io/v1/international?account_number=91833337&delivery_country=CA&height=2&length=19&value=0&weight=1&width=14"
    @carrier.expects(:commit).with([ url ]).returns([ json_fixture("newzealandpost/international_book") ])
    @carrier.find_rates(@wellington, @ottawa, @packages[:book])
  end

  def test_international_wii_request
    url = "http://shippingoptions-nzpg.au.cloudhub.io/v1/international?account_number=91833337&delivery_country=CA&height=12&length=39&value=269&weight=4&width=26"
    @carrier.expects(:commit).with([ url ]).returns([ json_fixture("newzealandpost/international_new_zealand_wii") ])
    @carrier.find_rates(@wellington, @ottawa, @packages[:new_zealand_wii])
  end

  def test_international_uk_wii_request
    url = "http://shippingoptions-nzpg.au.cloudhub.io/v1/international?account_number=91833337&delivery_country=CA&height=12&length=39&value=0&weight=4&width=26"
    @carrier.expects(:commit).with([ url ]).returns([ json_fixture("newzealandpost/international_wii") ])
    @carrier.find_rates(@wellington, @ottawa, @packages[:wii])
  end

  def test_international_small_half_pound_request
    url = "http://shippingoptions-nzpg.au.cloudhub.io/v1/international?account_number=91833337&delivery_country=CA&height=3&length=3&value=0&weight=1&width=3"
    @carrier.expects(:commit).with([ url ]).returns([ json_fixture("newzealandpost/international_small_half_pound") ])
    @carrier.find_rates(@wellington, @ottawa, @packages[:small_half_pound])
  end

  def test_international_book_response_params
    url = "http://shippingoptions-nzpg.au.cloudhub.io/v1/international?account_number=91833337&delivery_country=CA&height=2&length=19&value=0&weight=1&width=14"
    @carrier.expects(:commit).with([ url ]).returns([ json_fixture("newzealandpost/international_book") ])
    response = @carrier.find_rates(@wellington, @ottawa, @packages[:book])
    assert_equal [ url ], response.request
    assert_equal [ json_fixture("newzealandpost/international_book") ], response.raw_responses
    assert_equal [ JSON.parse(json_fixture("newzealandpost/international_book")) ], response.params["responses"]
  end

  def test_international_combined_request
    urls = [
      "http://shippingoptions-nzpg.au.cloudhub.io/v1/international?account_number=91833337&delivery_country=CA&height=2&length=19&value=0&weight=1&width=14",
      "http://shippingoptions-nzpg.au.cloudhub.io/v1/international?account_number=91833337&delivery_country=CA&height=3&length=3&value=0&weight=1&width=3"
    ]
    @carrier.expects(:commit).with(urls).returns([ json_fixture("newzealandpost/international_book"), json_fixture("newzealandpost/international_wii") ])
    @carrier.find_rates(@wellington, @ottawa, @packages.values_at(:book, :small_half_pound))
  end

  def test_international_combined_response_parsing
    @carrier.expects(:commit).returns([ json_fixture("newzealandpost/international_book"), json_fixture("newzealandpost/international_small_half_pound") ])
    response = @carrier.find_rates(@wellington, @ottawa, @packages.values_at(:book, :small_half_pound))
    assert_equal 4, response.rates.size
    assert_equal [ 19304, 12736, 7406, 6668 ], response.rates.map(&:price)
    assert_equal [ "ICPNDNA1", "IEZPDNA1", "IACNDNA1", "IECNDNA1" ], response.rates.map(&:service_code)
    names = [
      "Int Express Pcl Zone D 1.0kg",
      "Int Econ Cour Pcl Zn D 1.0kg",
      "Zone D AirPost Cust Pcl 1.0kg",
      "Zone D EconomyPost Pcl 1.0kg",
    ]
    assert_equal names, response.rates.map(&:service_name)
  end

  def test_international_empty_json_response_error
    @carrier.expects(:commit).returns([ "" ])
    error = @carrier.find_rates(@wellington, @ottawa, @packages[:book]) rescue $!
    assert_equal ActiveMerchant::Shipping::ResponseError, error.class
    assert_equal "A JSON text must at least contain two octets!", error.message
    assert_equal [ "" ], error.response.raw_responses
    response_params = { "responses" => [] }
    assert_equal response_params, error.response.params
  end

  def test_international_invalid_json_response_error
    @carrier.expects(:commit).returns([ "<>" ])
    error = @carrier.find_rates(@wellington, @ottawa, @packages[:book]) rescue $!
    assert_equal ActiveMerchant::Shipping::ResponseError, error.class
    assert error.message.include?("unexpected token")
    assert_equal [ "<>" ], error.response.raw_responses
    response_params = { "responses" => [] }
    assert_equal response_params, error.response.params
  end

  def test_international_invalid_origin_country_response
    error = @carrier.find_rates(@ottawa, @wellington, @packages[:book]) rescue $!
    assert_equal ActiveMerchant::Shipping::ResponseError, error.class
    assert_equal "New Zealand Post packages must originate in New Zealand", error.message
    assert_equal [], error.response.raw_responses
    assert_equal Array, error.response.request.class
    assert_equal 1, error.response.request.size
    response_params = { "responses" => [] }
    assert_equal response_params, error.response.params
  end

end
