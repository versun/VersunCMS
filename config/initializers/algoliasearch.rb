if ENV["ALGOLIASEARCH_APP_ID"].present? && ENV["ALGOLIASEARCH_API_KEY"].present?
  ENABLE_ALGOLIASEARCH = true
  AlgoliaSearch.configuration = {
    application_id: ENV["ALGOLIASEARCH_APP_ID"],
    api_key: ENV["ALGOLIASEARCH_API_KEY"],
    pagination_backend: :will_paginate
  }
end
