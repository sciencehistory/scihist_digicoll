// Bootstrap 5 popovers are opt-in, we need to activate them.
// https://getbootstrap.com/docs/5.0/components/popovers/#example-enable-popovers-everywhere

import { Popover } from 'bootstrap';

const popoverTriggerList = document.querySelectorAll('[data-bs-toggle="popover"]');
const popoverList = [...popoverTriggerList].map(popoverTriggerEl => new Popover(popoverTriggerEl));
