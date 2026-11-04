# AutoSwitcher

Автоматический переключатель раскладки клавиатуры для macOS. Открытый код, работает локально, ничего не отправляет в сеть.

## Что умеет

- Исправляет слово, набранное не в той раскладке, и переключает её: `ghbdtn` → `привет`, `руддщ` → `hello`.
- Двойной Shift отменяет последнее исправление.
- Не трогает поля паролей и терминалы. Свои исключения можно добавить в настройках.

## Установка

Нужны macOS 13 или новее, русская и английская раскладки и Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/semyonkorshukov-ux/AutoSwitcher.git
cd AutoSwitcher
./scripts/install.sh
```

Приложение соберётся на вашем Mac и появится в «Программах». В запросе macOS нажмите «Открыть Системные настройки» и включите AutoSwitcher в разделе «Универсальный доступ».

Для обновления выполните `git pull` и снова `./scripts/install.sh`. После каждого обновления доступ нужно включать заново.

## Лицензия

Код распространяется по лицензии [MIT](LICENSE). Словари в `Sources/AutoSwitcherCore/Resources/` взяты без изменений из [FrequencyWords](https://github.com/hermitdave/FrequencyWords) (автор Hermit Dave) и распространяются по [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
