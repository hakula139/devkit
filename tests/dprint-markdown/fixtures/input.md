#  Formatting   fixture

*Ordinary emphasis* and __ordinary strong__ show normalization.

- Relative indentation:

  ```text
    alpha
      beta
    gamma
  ```

- Blank lines:

  ```text

    first


    last

  ```

A result $$x + y = z$$ stays inside the paragraph.

<div>
<span>HTML keeps its indentation</span>
</div>

<!-- dprint-ignore -->
Adjacent references [^first] [^second] stay separated.

[^first]: First note.
[^second]: Second note.
