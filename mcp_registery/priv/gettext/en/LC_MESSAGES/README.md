This directory holds the English Gettext translation catalog used by Elixir's standard `Ecto.Changeset` error messages (`errors.po`). It contains the `msgid`/`msgstr` pairs Phoenix's `mix gettext.extract`/`mix gettext.merge` tasks generate for built-in validation errors like "can't be blank", "has already been taken", and "must be greater than %{number}".

Every `msgstr` here is intentionally left blank because English is the app's default locale, so Ecto's original English messages are already what gets shown — this file exists only as scaffolding for a future non-English translation, which the project does not currently use.

This is a generated i18n locale file with no direct effect on the live site: no page copy, layout, or user-facing feature at https://ai.mcpharbor.dev depends on its contents changing. It should not be hand-edited outside the normal `mix gettext` merge workflow.
