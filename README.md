<p align="center">
  <a href="#">
    <img src="https://github.com/andry81-cache/andry81-devops--gh-content-cache/raw/master/repo/andry81-devops/gh-workflow/badges/metrics/shields-repo-size.svg" valign="middle" alt="GitHub repo size in bytes" /></a>
<!-- -- >
• <a href="#">
    <img src="https://github.com/andry81-cache/andry81-devops--gh-content-cache/raw/master/repo/andry81-devops/gh-workflow/badges/metrics/shields-code-size.svg" valign="middle" alt="code size in bytes" /></a>
<!-- -->
• <a href="https://github.com/XAMPPRocky/tokei">
    <img src="https://github.com/andry81-cache/andry81-devops--gh-content-cache/raw/master/repo/andry81-devops/gh-workflow/badges/metrics/tokei-lines-of-code.svg" valign="middle" alt="lines of code by tokei.rs" /></a>
</p>

<p align="center">
  <a href="https://github.com/andry81-stats/gh-workflow--gh-stats/commits/master/traffic/views">
    <img src="https://github.com/andry81-cache/andry81-devops--gh-content-cache/raw/master/repo/andry81-devops/gh-workflow/badges/traffic/views/all.svg" valign="middle" alt="GitHub views|any|total" />
    <img src="https://github.com/andry81-cache/andry81-devops--gh-content-cache/raw/master/repo/andry81-devops/gh-workflow/badges/traffic/views/all-14d.svg" valign="middle" alt="GitHub views|any|14d" /></a>
• <a href="https://github.com/andry81-stats/gh-workflow--gh-stats/commits/master/traffic/views">
    <img src="https://github.com/andry81-cache/andry81-devops--gh-content-cache/raw/master/repo/andry81-devops/gh-workflow/badges/traffic/views/unq.svg" valign="middle" alt="GitHub views|unique per day|total" />
    <img src="https://github.com/andry81-cache/andry81-devops--gh-content-cache/raw/master/repo/andry81-devops/gh-workflow/badges/traffic/views/unq-14d.svg" valign="middle" alt="GitHub views|unique per day|14d" /></a>
</p>

<p align="center">
  <a href="https://github.com/andry81-stats/gh-workflow--gh-stats/commits/master/traffic/clones">
    <img src="https://github.com/andry81-cache/andry81-devops--gh-content-cache/raw/master/repo/andry81-devops/gh-workflow/badges/traffic/clones/all.svg" valign="middle" alt="GitHub clones|any|total" />
    <img src="https://github.com/andry81-cache/andry81-devops--gh-content-cache/raw/master/repo/andry81-devops/gh-workflow/badges/traffic/clones/all-14d.svg" valign="middle" alt="GitHub clones|any|14d" /></a>
• <a href="https://github.com/andry81-stats/gh-workflow--gh-stats/commits/master/traffic/clones">
    <img src="https://github.com/andry81-cache/andry81-devops--gh-content-cache/raw/master/repo/andry81-devops/gh-workflow/badges/traffic/clones/unq.svg" valign="middle" alt="GitHub clones|unique per day|total" />
    <img src="https://github.com/andry81-cache/andry81-devops--gh-content-cache/raw/master/repo/andry81-devops/gh-workflow/badges/traffic/clones/unq-14d.svg" valign="middle" alt="GitHub clones|unique per day|14d" /></a>
</p>

<p align="center">
  <a href="https://github.com/andry81-devops/gh-workflow/commits">
    <img src="https://github.com/andry81-cache/andry81-devops--gh-content-cache/raw/master/repo/andry81-devops/gh-workflow/badges/metrics/commits-since-latest.svg" valign="middle" alt="GitHub commits since latest version" /></a>
  <a href="https://github.com/andry81-devops/gh-workflow/releases">
    <img src="https://github.com/andry81-cache/andry81-devops--gh-content-cache/raw/master/repo/andry81-devops/gh-workflow/badges/metrics/latest-release-name.svg" valign="middle" alt="latest release name" /></a>
• <a href="https://github.com/andry81-devops/gh-workflow/releases">
    <img src="https://github.com/andry81-cache/andry81-devops--gh-content-cache/raw/master/repo/andry81-devops/gh-workflow/badges/metrics/github-all-releases.svg" valign="middle" alt="GitHub all releases" /></a>
</p>

<p align="center">
  <a href="https://github.com/andry81/donate"><img src="https://github.com/andry81-cache/gh-content-static-cache/raw/master/common/badges/donate/donate.svg" valign="middle" alt="donate" /></a>
</p>

---

<p align="center">
  <a href="https://github.com/andry81-devops/gh-workflow/tree/HEAD/userlog.md">Userlog</a>
• <a href="https://github.com/andry81-devops/gh-workflow/tree/HEAD/changelog.txt">Changelog</a>
• <a href="#dependentees">Dependentees</a>
• <a href="#copyright-and-license"><img src="https://github.com/andry81-cache/gh-content-static-cache/raw/master/common/badges/license/mit-license.svg" valign="middle" alt="copyright and license" />&nbsp;Copyright and License</a>
</p>

<h4 align="center">GitHub workflow support scripts.</h4>

Tutorials to use with: https://github.com/andry81/index#tutorials

##

# gh-workflow@master

## Dependentees

* All action scripts:<br />
  https://github.com/andry81/index#action-scripts

## Usage

### Local

1. Open Cygwin console, for example, in `bash/github` directory.

2. Set workflow root variables:

   ```console
   GH_WORKFLOW_ROOT=$(realpath ../..)
   ```

3. Run an initialization script:

   ```console
   . ./init-yq-workflow.sh
   ```

4. Run postponed initialization functions:

   ```console
   tkl_execute_calls gh
   ```

5. Run other functions...

To start over:

```console
tkl_unset_all_include_guards
```

## Copyright and License

Code and documentation copyright 2021 Andrey Dibrov. Code released under [MIT License](https://github.com/andry81-devops/gh-workflow/tree/HEAD/license.txt)
