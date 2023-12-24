# Cycle.Express

Buy cycles with fiat, and charge up your canisters on the [Internet Computer].

For how to use, please refer to [this document](doc/about.md), or our website https://cycle.express/.

For customer support, please directly mail to [support@cycle.express](mailto:support@cycle.express).

We use a typical client-server architecture, except that both are hosted in the same canister container on the [Internet Computer].
This technique is made possible by [Motoko Http Server].

- The backend server keeps transaction records, and integrates with [Stripe], a payment gateway service.
- HTML and Javascript frontend handles user input, shows payment link, and confirms after a successful payment.

The backend is written in [Motoko], and frontend in Javascript and Webpack.
Build environment requires [nodejs], [vessel] and [pandoc] to be in PATH.
Just type `make` to build both frontend and backend from source.

The deployment takes 2 steps:
- Deploy canister code with the required initialization parameters. This can be done from [ic-repl].
- Upload frontend assets to the canister. This can be done by using an [upload.js] script.

The deployed canister id is [4r37y-mqaaa-aaaab-aadqq-cai].

Unless otherwise noted, all source codes are released under [MIT License](LICENSE).

[Motoko]: https://github.com/dfinity/motoko
[vessel]: https://github.com/dfinity/vessel
[Motoko Http Server]: https://github.com/krpeacock/server
[Internet Computer]: https://wiki.internetcomputer.org
[4r37y-mqaaa-aaaab-aadqq-cai]: https://dashboard.internetcomputer.org/canister/4r37y-mqaaa-aaaab-aadqq-cai
[nodejs]: https://nodejs.org
[pandoc]: https://pandoc.org
[Stripe]: https://stripe.com
[upload.js]: https://github.com/krpeacock/server/blob/main/examples/http_greet/src/http_greet/upload.js
[ic-repl]: https://github.com/dfinity/ic-repl
