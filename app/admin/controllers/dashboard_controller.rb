module ActiveAdmin
  module Dashboards
    class DashboardController < ResourceController
      def index
        redirect_to "/product_page"
      end
    end
  end
end