package internal

import (
	"fmt"
	"os"
	"regexp"
)

func ReplaceOnce(path string, re *regexp.Regexp, replace string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	orig := string(data)
	out := re.ReplaceAllString(orig, replace)
	if out == orig {
		return fmt.Errorf("pattern not found in %s", path)
	}
	return os.WriteFile(path, []byte(out), 0644)
}

func ReplaceOnceFunc(path string, re *regexp.Regexp, fn func(string) string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	orig := string(data)
	out := re.ReplaceAllStringFunc(orig, fn)
	if out == orig {
		return fmt.Errorf("pattern not found in %s", path)
	}
	return os.WriteFile(path, []byte(out), 0644)
}
