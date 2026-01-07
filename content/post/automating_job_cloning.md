---
title: "Automating OpenQA Job Cloning with Python and YAML"
date: 2026-01-07
tags: ["openQA", "automation", "python", "devops", "testing", "scripting"]
categories: ["Workflow", "Development"]
---

## 🎉 Happy New Year! 

As anyone working with [OpenQA](https://open.qa/) knows, it is a powerful tool for automated testing. But sometimes, the workflow around re-triggering those tests for investigation purposes can feel a bit... *Manual*.

Recently, I found myself in a repetitive cycle while debugging complex test scenarios. My workflow looked something like this:

-  Take a known "good" job URL.
-  Open a scratchpad editor.
-  Craft a long `openqa-clone-job` command with tons of specific override parameters (`BUILD=0`, custom git branches, skipping specific modules, etc.).
-  Run the command in the terminal, wait for the output.
-  **Painfully visual scan of the terminal output**, to identify the newly created job URLs, and select them with my mouse, to copy them.
-  Paste them into [`openqa-mon`](https://github.com/os-autoinst/openqa-mon) or a text file to track their progress.

Till now I used a `Bash` script that kind of helped, but modifying giant arrays of arguments for every different debugging scenario was annoying and error-prone.

Then I realized that I needed to separate the **configuration** (the *what*—which jobs and parameters) from the **execution logic** (the *how*—running the command and extracting results).

Here is how I moved from a fragile Bash script to a robust `Python` and `YAML` automation workflow.

![messy_desk](https://www.theladders.com/wp-content/uploads/messy-desk-800x450.jpg)


## 🎯 "Infrastructure as Code" for Ad-Hoc Tests

I wanted a system where I could define a test scenario in a clean, readable file, run a single command, and immediately have the resulting job URLs ready for monitoring.

### Step 1: Defining the Configuration (YAML)

Instead of hardcoding variables inside a script, I moved them into a structured YAML file. This makes it incredibly easy to see exactly what a specific test run is supposed to do.

Here is an example config file, let's call it `krb5_ssh_test.yaml`:

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

This is readable, version-controllable, and easy to copy and modify for a different scenario.

### Step 2: The Automation Logic (Python)
While `Bash` is great for gluing commands together, `Python` excels at parsing structured data (YAML) and handling text output (Regex).

I wrote a Python script [clone_runner.py](https://github.com/ilmanzo/openqa-clone-runner) that does three main things:
  - Reads the YAML config and dynamically builds the `openqa-clone-job` command arguments.
  - Executes the command safely using Python's subprocess module.
  - Parses the output accurately. This was the key improvement: instead of me manually squinting at terminal text, `Python` uses regex to find lines like -> https://... and extracts the new URLs automatically.

Here is the crucial regex function that replaced my manual copy-pasting:

```Python
def extract_urls(output_text: str) -> List[str]:
    """Parses output looking for: '- jobname -> https://url...' """
    url_pattern = re.compile(r"->\s+(https?://\S+)")
    return url_pattern.findall(output_text)
```    

The script also automatically names the output file based on the config name. If I take parameters from `krb5_ssh_test.yaml`, it generates `krb5_ssh_test.urls.txt`.

## 😇 The New Workflow
Now, my workflow is streamlined and consistent.

I simply run the script pointing to my config file:

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

The final step is a seamless handoff to the monitoring tool:

```Bash
$ openqa-mon -i krb5_ssh_test.urls.txt
```

## 🎇 Conclusion

By spending a little time moving from an imperative Bash script to a declarative YAML configuration driven by Python, I've removed the most tedious and error-prone parts of starting ad-hoc [OpenQA](https://open.qa/) tests.
It’s a small automation improvement that pays dividends every single day, keeping my focus on the test results rather than the command line arguments.
Feel free to check the project and contribute at https://github.com/ilmanzo/openqa-clone-runner
