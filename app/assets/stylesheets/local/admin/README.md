These styles are meant to apply to our back-end/staff 'admin' screens.

We currently combine all our SCSS into one combined application.css that is delivered on both public-facing and staff-facing screens. So this CSS isn't really kept separated, and can affect public-facing screens, and public-facing-intended CSS can affect this stuff.

But we keep it in a separate subdir anyway, just for organizational purposes, to make it easier for devs to keep straight what is meant for what.
