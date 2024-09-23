// TODO: Import only what we need, for smaller size in builders that support it
import Chart from 'chart.js/auto';

class BlacklightRangeLimit {
  static init() {
    const range_limit = new BlacklightRangeLimit(document.querySelector(".range_limit .profile .distribution"));

    return range_limit;
  }

  constructor(container) {
    this.container = container;

    if (!this.container) {
      throw new Error("BlacklightRangeLimit missing argument")
    }

    this.whenBecomesVisible(container, target => this.setupIfNeeded());
  }

  setupIfNeeded() {
    const loadLink = this.container.querySelector("a.load_distribution");
    // we replace that link in DOM after loaded, so if it's there, we need to load
    if (!loadLink) {
      return;
    }

    fetch(loadLink["href"]).
      then( response => response.ok ? response.text() : Promise.reject(response)).
      then( responseBody => new DOMParser().parseFromString(responseBody, "text/html")).
      then( responseDom => responseDom.querySelector(".facet-values")).
      then( element =>  this.container.innerHTML = element.outerHTML ).
      catch( error => {
        console.error(error);
      });
  }

  // https://stackoverflow.com/a/70019478/307106
  whenBecomesVisible(element, callback) {
    const resizeWatcher = new ResizeObserver(entries => {
      for (const entry of entries) {
         if (entry.contentRect.width !== 0) {
           callback.call(entry.target);
         }
       }
    });
    resizeWatcher.observe(element);
  }
}

//export default class BlacklightRangeLimit;




window.rangeLimit = BlacklightRangeLimit.init();
