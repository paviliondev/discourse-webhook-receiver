import { default as discourseComputed, observes } from 'discourse-common/utils/decorators';
import { notEmpty } from "@ember/object/computed";
import WebhookReceiverLog from '../models/webhook-recevier-log';
import Controller from "@ember/controller";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse-common/config/environment";

export default Controller.extend({
  refreshing: false,
  hasLogs: notEmpty("logs"),
  page: 0,
  canLoadMore: true,
  logs: [],
  
  @observes("filter")
  loadLogs: discourseDebounce(function() {
    if (!this.canLoadMore) return;

    this.set("refreshing", true);
    
    const page = this.page;
    let params = {
      page
    }
    
    const filter = this.filter;
    if (filter) {
      params.filter = filter;
    }

    WebhookReceiverLog.list(params)
      .then(result => {
        if (!result || result.length === 0) {
          this.set('canLoadMore', false);
        }
        if (filter && page == 0) {
          this.set('logs', []);
        }
        
        let logs = this.get('logs');
        logs = logs.concat(result);
        this.set("logs", logs);
      })
      .finally(() => this.set("refreshing", false));
  }, INPUT_DELAY),
  
  @discourseComputed('hasLogs', 'refreshing')
  noResults(hasLogs, refreshing) {
    return !hasLogs && !refreshing;
  },
  
  actions: {
    loadMore() {
      let currentPage = this.get('page');
      this.set('page', currentPage += 1);
      this.loadLogs();
    },
    
    refresh() {
      this.setProperties({
        canLoadMore: true,
        page: 0,
        logs: []
      })
      this.loadLogs();
    }
  }
});