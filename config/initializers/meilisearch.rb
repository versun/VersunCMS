MeiliSearch::Rails.configuration = {
  meilisearch_url: ENV.fetch('MEILISEARCH_HOST', 'http://localhost:7700'),
  meilisearch_api_key: ENV.fetch('MEILISEARCH_API_KEY', 'YourMeilisearchAPIKey'),
  timeout: 2,
  max_retries: 1,
  index_settings: {
    'articles': {
      'prefixSearch': 'disabled',
      # 启用typo tolerance
      'typoTolerance': {
        'enabled': true,
        # 'minWordSizeForTypos': {
        #   'oneTypo': 4,  # 4个字符以上的词允许1个拼写错误
        #   'twoTypos': 8  # 8个字符以上的词允许2个拼写错误
        # }
      }
    }
  }
}