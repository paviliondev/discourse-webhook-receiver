import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import EmberObject from "@ember/object";

const WebhookReceiverLog = EmberObject.extend();

WebhookReceiverLog.reopenClass({
  list(params = {}) {
    return ajax('/admin/plugins/webhook-receiver', {
      data: params
    }).catch(popupAjaxError);
  }
});

export default WebhookReceiverLog;

