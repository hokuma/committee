require_relative "../test_helper"

describe Committee::Middleware::ResponseValidation do
  include Rack::Test::Methods

  def app
    @app
  end

  it "passes through a valid response" do
    @app = new_rack_app(JSON.generate([ValidApp]), {}, schema: hyper_schema)
    get "/apps"
    assert_equal 200, last_response.status
  end

  it "detects a response invalid due to schema" do
    @app = new_rack_app("{}", {}, schema: hyper_schema)
    get "/apps"
    assert_equal 500, last_response.status
    assert_match /{} is not an array/i, last_response.body
  end

  it "detects a response invalid due to not being JSON" do
    @app = new_rack_app("", {}, schema: hyper_schema)
    get "/apps"
    assert_equal 500, last_response.status
    assert_match /valid JSON/i, last_response.body
  end

  it "ignores a non-2xx invalid response" do
    @app = new_rack_app("[]", {}, app_status: 404, schema: hyper_schema)
    get "/apps"
    assert_equal 404, last_response.status
  end

  it "optionally validates non-2xx invalid responses" do
    @app = new_rack_app("", {}, app_status: 404, validate_errors: true,
      schema: hyper_schema)

    get "/apps"
    assert_equal 500, last_response.status
    assert_match /valid JSON/i, last_response.body
  end

  it "passes through a 204 (no content) response" do
    @app = new_rack_app("", {}, app_status: 204, schema: hyper_schema)
    get "/apps"
    assert_equal 204, last_response.status
  end

  it "rescues JSON errors" do
    @app = new_rack_app("[{x:y}]", {}, schema: hyper_schema)
    get "/apps"
    assert_equal 500, last_response.status
    assert_match /valid json/i, last_response.body
  end

  it "takes a prefix" do
    @app = new_rack_app(JSON.generate([ValidApp]), {}, prefix: "/v1",
      schema: hyper_schema)
    get "/v1/apps"
    assert_equal 200, last_response.status
  end

  it "rescues JSON errors" do
    @app = new_rack_app("[{x:y}]", {}, raise: true, schema: hyper_schema)
    assert_raises(Committee::InvalidResponse) do
      get "/apps"
    end
  end

  it "passes through a valid response for OpenAPI" do
    @app = new_rack_app(JSON.generate([ValidPet]), {},
      schema: open_api_2_schema)
    get "/api/pets"
    assert_equal 200, last_response.status
  end

  it "detects an invalid response for OpenAPI" do
    @app = new_rack_app("", {}, schema: open_api_2_schema)
    get "/api/pets"
    assert_equal 500, last_response.status
    assert_match /valid JSON/i, last_response.body
  end

  private

  def new_rack_app(response, headers = {}, options = {})
    headers = {
      "Content-Type" => "application/json"
    }.merge(headers)
    Rack::Builder.new {
      use Committee::Middleware::ResponseValidation, options
      run lambda { |_|
        [options.fetch(:app_status, 200), headers, [response]]
      }
    }
  end
end
