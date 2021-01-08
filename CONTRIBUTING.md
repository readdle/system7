## Contributing

First of, thanks for your interest in `s7`!

The following is a set of guidelines for contributing to System 7. These are mostly guidelines, not rules. Use your best judgment, and feel free to propose changes to this document in a pull request.

This project and everyone participating in it are governed by the [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

### Reporting Bugs & Suggesting Enhancements

https://github.com/readdle/system7/issues

### Code contribution  

We would happily accept your PR if:
 - it doesn't contradict the considerations described [here](Why%20custom%20submodules%20system.md). Even if your changes go across our considerations, we would be glad to discuss your suggestions – maybe you'll be able to change our mind. If not, you are always free to do whatever changes you like in your own fork of this project.
- there are tests for the stuff you change/add/fix. No compromises here. This project was written by TDD and I can't imagine how would it work and be stable without tests.

This project uses two types of tests:
 - unit tests when possible. As `s7` is tightly bound to Git hooks, some stuff cannot be tested with unit test, thus...
 - shell-script-based integration tests 
