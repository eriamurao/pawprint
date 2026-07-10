module Api
  class BaseController < ApplicationController
    skip_before_action :verify_authenticity_token

    rescue_from ActionController::ParameterMissing, with: :parameter_missing
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

    private

    def parameter_missing(exception)
      render json: { errors: [ "#{exception.param} is required" ] }, status: :bad_request
    end

    def record_not_found
      render json: { errors: [ 'Record not found' ] }, status: :not_found
    end
  end
end
