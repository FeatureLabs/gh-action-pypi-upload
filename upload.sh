#!/bin/sh

# Get tag from environment
tag=$(basename $GITHUB_REF)

# Get action that triggered release event
action=$(python -c "
import json

with open('$GITHUB_EVENT_PATH', 'r') as file:
    event = json.load(file)
    action = event.get('action')

print(action)
")

echo
echo "=================================================="
echo "Release $tag was $action on GitHub"
echo "=================================================="
echo

upload_to_pypi() {
    # Checkout release tag
    git checkout tags/$tag

    # Create virtualenv to download twine
    python -m venv venv
    . venv/bin/activate

    # Upgrade pip
    python -m pip install --upgrade pip -q

    # Install twine, module used to upload to pypi
    python -m pip install twine -q

    # Remove build artifacts
    artifacts=( ".eggs" "dist" "build" )
    for artifact in "${artifacts[@]}"
    do
    if [ -d $artifact ]; then rm -rf $artifact; fi
    done

    # Create distributions
    python setup.py -q sdist bdist_wheel

    # Upload to pypi or testpypi, overwrite if files already exist.
    python -m twine upload dist/* --skip-existing --verbose \
        --username $1 --password $2 --repository-url $3
}

release() {
    # Infers whether to upload to PyPI or Test PyPI.
    repository=$(python -c "
    import re

    pattern = '(?P<version>^v{n}.{n}.{n})(?P<suffix>.*)?'
    pattern = pattern.format(n='[0-9]+')
    pattern = re.compile(pattern)
    match = pattern.search('$tag')

    if match:
        match = match.groupdict()
        keys = ['version', 'suffix']
        version, suffix = map(match.get, keys)

        if version and not suffix:
            print('PyPI')

        if version and suffix.startswith('.dev'):
            print('Test PyPI')
    ")

    # If inference for PyPI, then upload to PyPI.
    if [ $repository = "PyPI" ]
    then
        TWINE_REPOSITORY_URL="https://upload.pypi.org/legacy/"
        upload_to_pypi $PYPI_USERNAME $PYPI_PASSWORD $TWINE_REPOSITORY_URL

    # Else if inference for Test PyPI, then upload to Test PyPI.
    elif [ $repository = "Test PyPI" ]
    then
        TWINE_REPOSITORY_URL="https://test.pypi.org/legacy/"
        upload_to_pypi $TEST_PYPI_USERNAME $TEST_PYPI_PASSWORD $TWINE_REPOSITORY_URL

    # Else, raise an error and exit.
    else
        echo "Unable to make inference on release $tag"
        exit 1
    fi
}

# If release was published on GitHub then release to PyPI.
if [ $action = "published" ]; then release; fi