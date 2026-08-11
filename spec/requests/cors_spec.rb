require 'rails_helper'

RSpec.describe 'CORS', type: :request do
  describe 'OPTIONS /api/v1/tasks' do
    it 'returns CORS headers for the allowed origin' do
      options '/api/v1/tasks', headers: {
        'Origin' => 'http://localhost:5173',
        'Access-Control-Request-Method' => 'GET'
      }

      expect(response.headers['Access-Control-Allow-Origin']).to eq('http://localhost:5173')
    end
  end
end
