import { App } from "./app";
import { Library } from "./library";
import { ModelClient } from "./model/model-client";
import { LibraryStore } from "./storage/library-store";
import { loadSettings } from "./storage/settings";
import { getElements } from "./ui/elements";

const settings = loadSettings();
const app = new App(
  getElements(),
  new Library(new LibraryStore(), settings.persistLibrary),
  new ModelClient(),
  settings,
);

app.start().catch((error: unknown) => {
  console.error("mnesia failed to start", error);
});
