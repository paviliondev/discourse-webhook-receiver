import WebhookReceiverLog from '../models/webhook-receiver-log';
import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  model() {
    return WebhookReceiverLog.list();
  },
  
  setupController(controller, model) {
    controller.set('logs', model);
  }
})