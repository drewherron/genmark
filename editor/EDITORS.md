# Editor Integration

Syntax highlighting, folding, indentation, and comment support for Genmark
(`.gmd`) files.

---

## Emacs

Copy or symlink `emacs/genmark-mode.el` somewhere in your load path, then:

```elisp
(require 'genmark-mode)
```

Or with `use-package`:

```elisp
(use-package genmark-mode
  :load-path "/path/to/genmark/editor/emacs")
```

Then `.gmd` files will activate the mode automatically.

**Key bindings:**

| Key        | Action                                                    |
|------------|-----------------------------------------------------------|
| `TAB`      | Toggle fold on headings, indent on field lines            |
| `S-TAB`    | Toggle all folds                                          |
| `RET`      | Newline with auto-indent (double RET returns to column 0) |
| `M-;`      | Toggle `//` comment on current line                       |
| `M-<up>`   | Move entire block up                                      |
| `M-<down>` | Move entire block down                                    |
| `C-c ^`    | Sort blocks (by birth date or name)                       |

Sort works on selection if there is one, if not it sorts the whole file.
Keep in mind that it won't sort independent comment blocks, so be careful
sorting if you have comment-defined sections in your file (i.e., just sort
in selected regions).

---

## Vim / Neovim

Add the plugin directory to your runtime path. In `~/.vimrc` or
`~/.config/nvim/init.vim`:

```vim
set runtimepath+=~/path/to/genmark/editor/vim
```

**Important:** This line must appear *before* `filetype plugin on` (or
`plug#end()`, which calls it internally). If the runtimepath is added
after filetype detection has already run, the `ftdetect/` directory won't
be scanned and `.gmd` files won't be recognized.

Or symlink the individual directories (`ftdetect`, `syntax`, `ftplugin`,
`indent`) into `~/.vim/` or `~/.config/nvim/`.

`.gmd` files activate the filetype automatically.

**Key bindings:**

| Key       | Action                                              |
|-----------|-----------------------------------------------------|
| `Tab`     | Toggle fold on headings, indent on other lines      |
| `S-Tab`   | Toggle all folds                                    |
| `Enter`   | Newline with auto-indent (double Enter returns to column 0) |

Comment toggling works with plugins like vim-commentary (`gcc`).

---

## VS Code

Copy or symlink the `vscode/` directory into your extensions folder:

```
# Linux/macOS
cp -r vscode ~/.vscode/extensions/genmark

# Or symlink
ln -s /path/to/genmark/editor/vscode ~/.vscode/extensions/genmark
```

Restart VS Code. `.gmd` files activate the language mode automatically.

VS Code's built-in `Ctrl+/` and `Shift+Alt+A` work for toggling comments.
Folding and indentation are handled natively based on the language
configuration.

## Author's Note

I only use Emacs, so that file is much more comprehensive.
I'd welcome any useful contributions to other editors.
