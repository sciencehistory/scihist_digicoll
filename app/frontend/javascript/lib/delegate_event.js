/*

   We want something like JQuery 'on', but without JQuery:
       https://api.jquery.com/on/

   This is a bit tricky to get right. We cribbed this implementation from:

  https://stackoverflow.com/a/25248515/


  If in JQuery you'd do:

     $(document).on("click", <selector>, handler)

  Now do something like:

    import delegateEvent from './lib/delegate_event.js';

    delegateEvent(document, "click", <selector>, handler);

ALL ARGS ARE REQUIRED for now.

*/

export default function delegateEvent(container, event, selectorStr, handler) {
  container.addEventListener(event, function(e) {
      for (var target=e.target; target && target!=container; target=target.parentNode) {
      // loop parent nodes from the target to the delegation node
          if (target.matches(selectorStr)) {
              handler.call(target, e);
              break;
          }
      }
  }, false);
};
