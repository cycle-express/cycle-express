# Cycle.Express

Buy cycles with fiat, and charge up your canisters on the [Internet Computer].

For how to use, please refer to [this document](doc/about.md), or our website https://cycle.express/.

For customer support, please directly mail to [support@cycle.express](mailto:support@cycle.express).

We use a typical client-server architecture, except that both are hosted in the same canister container on the [Internet Computer].
This technique is made possible by [Motoko Http Server].

- The backend server takes care of transaction records, and integration with [Stripe], a payment gateway service.
- HTML and Javascript frontend handles user input, shows payment link, and confirmation after a successful payment.

The backend code is written in [Motoko], and we primarily uses [vessel] as the build tool to build the project.
Just type `make` to build both frontend and backend from source.

The deployment takes 2 steps:
- Deploy canister code with the required initialization parameters.
- Upload frontend assets to the canister.

The deployed canister id is [4r37y-mqaaa-aaaab-aadqq-cai].

To improve transparency and verifiability, we release all source code under [MIT License](LICENSE).

[Motoko]: https://github.com/dfinity/motoko
[vessel]: https://github.com/dfinity/vessel
[Motoko Http Server]: https://github.com/krpeacock/server
[Internet Computer]: https://wiki.internetcomputer.org
[4r37y-mqaaa-aaaab-aadqq-cai]: https://dashboard.internetcomputer.org/canister/4r37y-mqaaa-aaaab-aadqq-cai

