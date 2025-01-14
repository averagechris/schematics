import json
from collections.abc import Mapping, Sequence
from typing import Optional, Type

from .datastructures import FrozenDict, FrozenList
from .translator import LazyText

__all__ = [
    "BaseError",
    "ErrorMessage",
    "FieldError",
    "ConversionError",
    "ValidationError",
    "StopValidationError",
    "CompoundError",
    "DataError",
    "MockCreationError",
    "UndefinedValueError",
    "UnknownFieldError",
]


class BaseError(Exception):
    def __init__(self, errors):
        """
        The base class for all Schematics errors.

        message should be a human-readable message,
        while errors is a machine-readable list, or dictionary.

        if None is passed as the message, and error is populated,
        the primitive representation will be serialized.

        the Python logging module expects exceptions to be hashable
        and therefore immutable. As a result, it is not possible to
        mutate BaseError's error list or dict after initialization.
        """
        errors = self._freeze(errors)
        super().__init__(errors)

    @property
    def errors(self):
        return self.args[0]

    def to_primitive(self):
        """
        converts the errors dict to a primitive representation of dicts,
        list and strings.
        """
        try:
            return self._primitive
        except AttributeError:
            self._primitive = self._to_primitive(self.errors)
            return self._primitive

    @staticmethod
    def _freeze(obj):
        """freeze common data structures to something immutable."""
        if isinstance(obj, dict):
            return FrozenDict(obj)
        if isinstance(obj, list):
            return FrozenList(obj)
        return obj

    @classmethod
    def _to_primitive(cls, obj):
        """recursive to_primitive for basic data types."""
        if isinstance(obj, str):
            return obj
        if isinstance(obj, Sequence):
            return [cls._to_primitive(e) for e in obj]
        if isinstance(obj, Mapping):
            return dict((k, cls._to_primitive(v)) for k, v in obj.items())
        return str(obj)

    def __str__(self):
        return json.dumps(self.to_primitive())

    def __repr__(self):
        return f"{self.__class__.__name__}({self.errors!r})"

    def __hash__(self):
        return hash(self.errors)

    def __eq__(self, other):
        if type(self) is type(other):
            return self.errors == other.errors
        return self.errors == other

    def __ne__(self, other):
        return not (self == other)


class ErrorMessage:
    def __init__(self, summary, info=None):
        self.type = None
        self.summary = summary
        self.info = info

    def __repr__(self):
        return f"{self.__class__.__name__}({self.summary!r}, {self.info!r})"

    def __str__(self):
        if self.info:
            return f"{self.summary}: {self._info_as_str()}"
        return str(self.summary)

    def _info_as_str(self):
        if isinstance(self.info, int):
            return str(self.info)
        if isinstance(self.info, str):
            return f'"{self.info}"'
        return str(self.info)

    def __eq__(self, other):
        if isinstance(other, ErrorMessage):
            return (
                self.summary == other.summary
                and self.type == other.type
                and self.info == other.info
            )
        if isinstance(other, str):
            return self.summary == other
        return False

    def __ne__(self, other):
        return not (self == other)

    def __hash__(self):
        return hash((self.summary, self.type, self.info))


class FieldError(BaseError, Sequence):

    type: Optional[Type[Exception]] = None

    def __init__(self, *args, **kwargs):

        if type(self) is FieldError:
            raise NotImplementedError(
                "Please raise either ConversionError or ValidationError."
            )
        if len(args) == 0:
            raise TypeError("Please provide at least one error or error message.")
        if kwargs:
            items = [ErrorMessage(*args, **kwargs)]
        elif len(args) == 1:
            arg = args[0]
            if isinstance(arg, list):
                items = list(arg)
            else:
                items = [arg]
        else:
            items = args
        errors = []
        for item in items:
            if isinstance(item, (str, LazyText)):
                errors.append(ErrorMessage(str(item)))
            elif isinstance(item, tuple):
                errors.append(ErrorMessage(*item))
            elif isinstance(item, ErrorMessage):
                errors.append(item)
            elif isinstance(item, self.__class__):
                errors.extend(item.errors)
            else:
                raise TypeError(
                    f"'{type(item).__name__}()' object is neither a {type(self).__name__} nor an error message."
                )
        for error in errors:
            error.type = self.type or type(self)

        super().__init__(errors)

    def __contains__(self, value):
        return value in self.errors

    def __getitem__(self, index):
        return self.errors[index]

    def __iter__(self):
        return iter(self.errors)

    def __len__(self):
        return len(self.errors)


class ConversionError(FieldError, TypeError):
    """Exception raised when data cannot be converted to the correct python type"""


class ValidationError(FieldError, ValueError):
    """Exception raised when invalid data is encountered."""


class StopValidationError(ValidationError):
    """Exception raised when no more validation need occur."""

    type = ValidationError


class CompoundError(BaseError):
    def __init__(self, errors):
        if not isinstance(errors, dict):
            raise TypeError("Compound errors must be reported as a dictionary.")
        for key, value in errors.items():
            if isinstance(value, CompoundError):
                errors[key] = value.errors
            else:
                errors[key] = value
        super().__init__(errors)


class DataError(CompoundError):
    def __init__(self, errors, partial_data=None):
        super().__init__(errors)
        self.partial_data = partial_data


class MockCreationError(ValueError):
    """Exception raised when a mock value cannot be generated."""


class UndefinedValueError(AttributeError, KeyError):
    """Exception raised when accessing a field with an undefined value."""

    def __init__(self, model, name):
        msg = f"'{model.__class__.__name__}' instance has no value for field '{name}'"
        super().__init__(msg)


class UnknownFieldError(KeyError):
    """Exception raised when attempting to access a nonexistent field using the subscription syntax."""

    def __init__(self, model, name):
        msg = f"Model '{model.__class__.__name__}' has no field named '{name}'"
        super().__init__(msg)
