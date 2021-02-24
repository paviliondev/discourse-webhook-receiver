## Discourse Webhook Receiver

This plugin allows you to process webhook payloads from other services in Discourse. Currently it's focused on receiving webhook payloads from Shopify for the management of user groups.

### Authentication

The two ``receiver_secret`` site settings must be filled out, e.g. for a shopify webhook:

webhook_receiver_secret: '01534563e5423423534234td36b33459d25ead5d97c6f6165643656fa797eec434f'
webhook_receiver_secret_header_key: 'X-Shopify-Hmac-SHA256'

### Receiver payload paths

The two payload path settings must be filled out

webhook_receiver_payload_key_path. This is the path to the key for one of two uses cases:

  - to use in a subsequent ``post_receipt_request`` to retrieve more data; or
  - to use in the key_group map if ``post_receipt_request`` is disabled.

webhook_receiver_payload_email_path. This is the path to the email to use to lookup the relevant user.

### Receiver post-receipt request

Some webhook receipts require a subsequent request back to the sender service for more information. You can interpolate the key obtained from the payload into the ``webhook_receiver_post_receipt_request_url``.

The response to the post-receipt request will be used to update the key to be used in the key_group_map.

### Key group mapping

The ``webhook_receiver_key_group_map`` is used to add users to group if the value for the key in the initial payload, or the post-receipt request payload, matches the group name.