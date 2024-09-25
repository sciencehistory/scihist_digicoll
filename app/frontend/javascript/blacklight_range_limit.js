// TODO: Import only what we need, for smaller size in builders that support it
import Chart from 'chart.js/auto';
// things we need:
// filler


class BlacklightRangeLimit {
  static init() {
    const range_limit = new BlacklightRangeLimit(document.querySelector(".range_limit .profile .distribution"));

    return range_limit;
  }

  rangeBuckets = []; // array of objects with bucket range info

  xTicks = []; // array of x values to use as chart ticks

  lineDataPoints = [] // array of objects in Chart.js line chart data format, { x: xVal, y: yVal }

  // <canvas> DOM element
  chartCanvasElement;

  // container should be div.distribution that includes the fetch ranges link, and will
  // be replaced by the chart.
  constructor(container) {
    this.container = container;

    if (!this.container) {
      throw new Error("BlacklightRangeLimit missing argument")
    }

    // Delay setup until someone clicks to open the facet, mainly to avoid making
    // extra http request to server if it will never be needed!
    this.whenBecomesVisible(container, target => this.setup());
  }

  // if the range fetch link is still in DOM, fetch ranges from back-end,
  // create chart element in DOM (replacing existing fetch link), chart
  // with chart.js, store state in instance variables.
  //
  // This is idempotent in that it will no-op if a.load_distribution has already
  // been removed from dom, which it does.
  setup() {
    const loadLink = this.container.querySelector("a.load_distribution");
    // we replace that link in DOM after loaded, so if it's there, we need to load
    if (!loadLink) {
      return;
    }

    fetch(loadLink["href"]).
      then( response => response.ok ? response.text() : Promise.reject(response)).
      then( responseBody => new DOMParser().parseFromString(responseBody, "text/html")).
      then( responseDom => responseDom.querySelector(".facet-values")).
      then( element =>  this.container.innerHTML = element.outerHTML  ).
      then( _ => {
        //  class chart_js on container indicates charting is enabled in config
        if (this.container.classList.contains("chart_js")) {
          this.extractBucketData();
          this.chartCanvasElement = this.setupDomForChart();
          this.drawChart(this.chartCanvasElement);
        }

      }).
      catch( error => {
        console.error(error);
      });
  }

  // Extract our bucket ranges from HTML DOM, and store in our instance variables
  extractBucketData(facetListDom = this.container.querySelector(".facet-values")) {
    this.rangeBuckets = Array.from(facetListDom.querySelectorAll("ul.facet-values li")).map( li => {
      let from    = this.parseNum(li.querySelector("span.from")?.getAttribute("data-blrl-begin") || li.querySelector("span.single")?.getAttribute("data-blrl-single"));
      let to      = this.parseNum(li.querySelector("span.to")?.getAttribute("data-blrl-end") || li.querySelector("span.single")?.getAttribute("data-blrl-single"));
      let count   = this.parseNum(li.querySelector("span.facet-count,span.count").innerText);
      let avg     = (count / (to - from + 1));

      return {
        from: from,
        to: to,
        count: count,
        avg: avg,
      }
    });

    // Points to graph on our line chart to make it look like a histogram.
    // We use the avg as the y-coord, to make the area of each
    // segment proportional to how many documents it holds.
    this.rangeBuckets.forEach(bucket => {
      this.lineDataPoints.push({ x: bucket.from, y: bucket.avg });
      this.lineDataPoints.push({ x: bucket.to + 1, y: bucket.avg });

      this.xTicks.push(bucket.from);
    });

    // remove first and last tick, they are likely to be uneven unhelpful
    this.xTicks.shift();
    this.xTicks.pop();

    return undefined;
  }

  setupDomForChart() {
    // We keep the textual facet data as accessible screen-reader, add .sr-only to it though
    let listDiv = this.container.querySelector(".facet-values");
    //listDiv.classList.add("sr-only");
    // and hide the legend as to total range sr-only too
    //this.container.closest(".profile").querySelector("p.range").classList.add("sr-only");

    // We create a <chart>, insert it into DOM before listDiv
    this.chartCanvasElement = this.container.ownerDocument.createElement("canvas");
    this.chartCanvasElement.classList.add("blacklight-range-limit-chart");
    this.container.insertBefore(this.chartCanvasElement, listDiv);

    return this.chartCanvasElement;
  }

  // Draw chart to a <canvas> element
  //
  // Somehow this method should be locally over-rideable if you want to change parameters for chart, just
  // override and draw the chart how you want?
  drawChart(chartCanvasElement) {
    new Chart(chartCanvasElement.getContext("2d"), {
      type: 'line',
      options: {
        // disable all animations
        animation: {
            duration: 0 // general animation time
        },
        hover: {
            animationDuration: 0 // duration of animations when hovering an item
        },
        responsiveAnimationDuration: 0,

        plugins: {
          legend: false
        },
        elements: {
          // hide points, and hide hover tooltip, which is not useful in our simulated histogram
          point: {
            radius: 0
          }
        },
        scales: {
          x: {
            beginAtZero: false, // we really do NOT want to beginAtZero
            type: 'linear',
            min: 1809,
            max: 2023,
            afterBuildTicks: axis => {
              // will autoskip to remove ticks that don't fit, but give it our segment boundaries
              // to start with
              axis.ticks = this.xTicks.map(v => ({ value: v }))
            },
            ticks: {
              autoSkip: true, // supposed to skip when can't fit, but does not always work
              maxRotation: 0,
              maxTicksLimit: 4, // try a number that should fit
              callback: (val, index) => {
                // Don't format for locale, these are years, just display as years.
                return val;
                //
              }
            }
          },
          y: {
            beginAtZero: true,
            // hide axis labels and grid lines on y, to save space and
            // because it's kind of meant to be relative?
            ticks: {
              display: false,
            },
            grid: {
              display: false
            }
          }
        },
      },
      data: {
        datasets: [
          {
            data: this.lineDataPoints,
            stepped: true,
            fill: true,
            // hide segments tha just go y 0 to 0 along the bottom
            segment: {
              borderColor: ctx => {
                return (ctx.p0.parsed.y == 0 && ctx.p1.parsed.y == 0) ? 'transparent' : undefined;
              },
            }
            // Fill color under line:
            //backgroundColor: 'pink'
          }
        ]
      }
    });
  }

  // takes a string and parses into an integer, but throws away commas first, to avoid truncation when there is a comma
  // use in place of javascript's native parseInt
  parseNum(str) {
    return parseInt( String(str).replace(/[^0-9-]/g, ''), 10);
  }

  // https://stackoverflow.com/a/70019478/307106
  whenBecomesVisible(element, callback) {
    const resizeWatcher = new ResizeObserver((entries, observer) => {
      for (const entry of entries) {
         if (entry.contentRect.width !== 0 && entry.contentRect.height !== 0) {
           callback.call(entry.target);
           // turn off observing, we only fire once
           observer.unobserve(entry.target);
         }
       }
    });
    resizeWatcher.observe(element);
  }
}

//export default class BlacklightRangeLimit;




window.rangeLimit = BlacklightRangeLimit.init();
