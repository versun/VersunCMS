<figure class="attachment attachment--file attachment--{{blob.filename.extension}}">
  <img src="{{site_settings.get('url', '')}}{{blob_url}}" alt="{{blob.filename}}" />

  <figcaption class="attachment__caption">
    % if hasattr(blob, 'caption') and blob.caption:
      {{blob.caption}}
    % else:
      <span class="attachment__name">{{blob.filename}}</span>
      <span class="attachment__size">{{blob.byte_size_human}}</span>
    % end
  </figcaption>
</figure>
