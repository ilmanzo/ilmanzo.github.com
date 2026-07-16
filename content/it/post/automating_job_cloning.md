---
title: "Automatizzare la clonazione dei job OpenQA con Python e YAML"
date: 2026-01-07
tags: ["openQA", "automation", "python", "devops", "testing", "scripting"]
categories: ["Workflow", "Development"]
---

## 🎉 Buon anno nuovo!

Come sa chiunque lavori con [openQA](https://open.qa/), si tratta di uno strumento estremamente potente per i test automatizzati. Tuttavia, a volte il flusso di lavoro necessario per riattivare i test a scopo di analisi può sembrare un po'... *manuale*.

Di recente mi sono ritrovato in un ciclo ripetitivo durante il debug di scenari di test complessi. Il mio flusso di lavoro si presentava all'incirca così:

- Individuare l'URL di un job noto come "corretto".
- Aprire un editor di appunti veloce.
- Comporre un lungo comando `openqa-clone-job` con una marea di parametri di override specifici (`BUILD=0`, branch Git personalizzati, esclusione di moduli specifici, ecc.).
- Eseguire il comando nel terminale e attendere l'output.
- **Scansionare visivamente con fatica l'output del terminale** per individuare gli URL dei nuovi job creati, selezionandoli con il mouse per copiarli.
- Incollarli in [`openqa-mon`](https://github.com/os-autoinst/openqa-mon) o in un file di testo per monitorarne l'avanzamento.

Fino a questo momento ho utilizzato uno script `Bash` che in un certo senso mi aiutava, ma modificare array giganteschi di argomenti per ogni diverso scenario di debug era noioso e incline all'errore.

Poi ho capito che dovevo separare la **configurazione** (il *cosa* — quali job e quali parametri) dalla **logica di esecuzione** (il *come* — l'esecuzione del comando e l'estrazione dei risultati).

Ecco come sono passato da un fragile script Bash a un flusso di lavoro di automazione robusto basato su `Python` e `YAML`.

![messy_desk](https://www.theladders.com/wp-content/uploads/messy-desk-800x450.jpg)


## 🎯 "Infrastructure as Code" per i test ad-hoc

Volevo un sistema in cui poter definire uno scenario di test all'interno di un file pulito e leggibile, eseguire un unico comando e avere immediatamente gli URL dei job risultanti pronti per essere monitorati.

### Fase 1: Definire la configurazione (YAML)

Invece di scrivere le variabili in modo rigido all'interno dello script, le ho spostate in un file YAML strutturato. Questo rende incredibilmente facile capire esattamente cosa debba fare una determinata esecuzione di test.

Ecco un esempio di file di configurazione, che chiameremo `krb5_ssh_test.yaml`:

```yaml
# krb5_ssh_test.yaml

# The parent jobs to clone from
jobs_to_clone:
  - https://openqa.opensuse.org/tests/123456
  - https://openqa.opensuse.org/tests/789012

# Command line flags
flags:
  - "--clone-children"
  - "--skip-deps"

# Environment variables and parameters
variables:
  _GROUP_ID: 38
  BUILD: "my-custom-build"
  # Pointing to my custom test branch
  CASEDIR: "https://github.com/ilmanzo/os-autoinst-distri-opensuse.git#my_custom_branch"
  _SKIP_POST_FAIL_HOOKS: 1
  QEMURAM: 2048
```

Questo formato è leggibile, può essere tracciato con sistemi di controllo versione ed è facile da copiare e modificare per scenari differenti.

### Fase 2: La logica di automazione (Python)
Se da un lato `Bash` è ottima per concatenare comandi, dall'altro `Python` eccelle nel parsing di dati strutturati (YAML) e nella manipolazione di testo (Regex).

Ho scritto uno script Python [clone_runner.py](https://github.com/ilmanzo/openqa-clone-runner) che si occupa principalmente di tre cose:
  - Leggere la configurazione YAML e costruire dinamicamente gli argomenti per il comando `openqa-clone-job`.
  - Eseguire il comando in modo sicuro usando il modulo `subprocess` di Python.
  - Effettuare il parsing dell'output con precisione. Questo è stato il miglioramento chiave: invece di dover analizzare manualmente il testo nel terminale, `Python` usa le espressioni regolari per individuare righe come `-> https://...` ed estrarre automaticamente i nuovi URL.

Ecco la funzione regex cruciale che ha sostituito il mio copia-incolla manuale:

```Python
def extract_urls(output_text: str) -> List[str]:
    """Parses output looking for: '- jobname -> https://url...' """
    url_pattern = re.compile(r"->\s+(https?://\S+)")
    return url_pattern.findall(output_text)
```    

Lo script assegna anche automaticamente il nome al file di output in base al nome del file di configurazione. Se utilizzo i parametri di `krb5_ssh_test.yaml`, genererà `krb5_ssh_test.urls.txt`.

## 😇 Il nuovo flusso di lavoro
Ora il mio flusso di lavoro è snello e coerente.

Mi basta eseguire lo script indicando il file di configurazione:

```Bash
$ ./clone_runner.py -c krb5_ssh_test.yaml
```
Output:

```
- Starting clone process using config: krb5_ssh_test.yaml
- Output will be saved to: krb5_ssh_test.urls.txt

Processing: https://openqa.suse.de/tests/20438098
   - Extracted 4 new job URLs.

Processing: https://openqa.suse.de/tests/20394793
   - Extracted 6 new job URLs.

========================================
Success! URLs saved to 'krb5_ssh_test.urls.txt'
You can now run:
   openqa-mon -i krb5_ssh_test.urls.txt
========================================
```

L'ultimo passaggio consiste nel passare i dati direttamente allo strumento di monitoraggio:

```Bash
$ openqa-mon -i krb5_ssh_test.urls.txt
```

## 🪚 Conclusione

Dedicando un po' di tempo al passaggio da un imperativo script Bash a una configurazione dichiarativa in YAML gestita tramite Python, ho eliminato le parti più noiose e soggette a errori dell'avvio dei test ad-hoc su [openQA](https://open.qa/).
Si tratta di un piccolo miglioramento nell'automazione che ripaga ogni singolo giorno, consentendomi di concentrarmi sui risultati dei test anziché sugli argomenti della riga di comando.
Ti invito a dare un'occhiata al progetto e a contribuire su https://github.com/ilmanzo/openqa-clone-runner