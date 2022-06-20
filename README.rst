About
=====

This is a Fork from the hard work of the maintainers at
https://github.com/schematics/schematics.

Here's a summary of the changes:

+ add support for python 3.10+
+ drop support for python version 3.6, 3.7, and 3.8
+ run black and isort on the code base
+ package with flit, updating to pyproject.toml
+ add development environment setup with nix and package as a nix flake.
+ and that's it!

I don't plan on any changes to this library aside from maintaining
support for modern python versions as long as this library is still
a dependency for projects that I'm involved with which is unlikely to
be forever. I would recommend planning on porting your validation code
to another validation / serialization library that is actively maintained.
But until then I'll do my best to keep this current with new python
versions. Thank you to the original maintainers for all of their work!

**Project documentation:** https://schematics.readthedocs.io/en/latest/

Schematics is a Python library to combine types into structures, validate them,
and transform the shapes of your data based on simple descriptions.

The internals are similar to ORM type systems, but there is no database layer
in Schematics.  Instead, we believe that building a database
layer is made significantly easier when Schematics handles everything but
writing the query.

Further, it can be used for a range of tasks where having a database involved
may not make sense.

Some common use cases:

+ Design and document specific `data structures <https://schematics.readthedocs.io/en/latest/usage/models.html>`_
+ `Convert structures <https://schematics.readthedocs.io/en/latest/usage/exporting.html#converting-data>`_ to and from different formats such as JSON or MsgPack
+ `Validate <https://schematics.readthedocs.io/en/latest/usage/validation.html>`_ API inputs
+ `Remove fields based on access rights <https://schematics.readthedocs.io/en/latest/usage/exporting.html>`_ of some data's recipient
+ Define message formats for communications protocols, like an RPC
+ Custom `persistence layers <https://schematics.readthedocs.io/en/latest/usage/models.html#model-configuration>`_


Example
=======

This is a simple Model. 

.. code:: python

  >>> from schematics.models import Model
  >>> from schematics.types import StringType, URLType
  >>> class Person(Model):
  ...     name = StringType(required=True)
  ...     website = URLType()
  ...
  >>> person = Person({'name': u'Joe Strummer',
  ...                  'website': 'http://soundcloud.com/joestrummer'})
  >>> person.name
  u'Joe Strummer'

Serializing the data to JSON.

.. code:: python

  >>> import json
  >>> json.dumps(person.to_primitive())
  {"name": "Joe Strummer", "website": "http://soundcloud.com/joestrummer"}

Let's try validating without a name value, since it's required.

.. code:: python

  >>> person = Person()
  >>> person.website = 'http://www.amontobin.com/'
  >>> person.validate()
  Traceback (most recent call last):
    File "<stdin>", line 1, in <module>
    File "schematics/models.py", line 231, in validate
      raise DataError(e.messages)
  schematics.exceptions.DataError: {'name': ['This field is required.']}

Add the field and validation passes.

.. code:: python

  >>> person = Person()
  >>> person.name = 'Amon Tobin'
  >>> person.website = 'http://www.amontobin.com/'
  >>> person.validate()
  >>>
