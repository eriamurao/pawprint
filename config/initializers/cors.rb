Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins Rails.env.production? ? ENV.fetch('PAWPRINT_UI_URL') : 'http://localhost:5173'
    resource '/api/*',
      headers: [ 'Authorization', 'Content-Type', 'Accept' ],
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ]
  end
end
