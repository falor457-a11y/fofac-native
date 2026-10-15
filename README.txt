fofac — нативное приложение (SwiftUI). Данные (вопросы, времена, словарь) лежат в Resources/data.json.

1. На GitHub создай НОВЫЙ репозиторий (например fofac-native), Public.
2. Загрузи в него содержимое этой папки: Sources, Resources, project.yml.
3. Папку .github Windows часто не даёт перетащить. Создай файл на сайте:
   Add file -> Create new file -> имя  .github/workflows/ios.yml
   и вставь туда содержимое файла ios.yml из этой папки.
4. Actions -> Build IPA -> Run workflow. Ждать ~5-10 минут.
5. Скачай fofac-ipa, распакуй, поставь fofac.ipa через AltStore (My Apps -> "+").
Если сборка упала, открой упавший шаг и пришли текст ошибки.
