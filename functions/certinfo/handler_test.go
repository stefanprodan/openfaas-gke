package function

import (
	"regexp"
	"testing"
)

func TestHandleReturnsCorrectResponse(t *testing.T) {
	expected := "Google Internet Authority"
	resp := Handle([]byte("google.com"))

	r := regexp.MustCompile("(?m:" + expected + ")")
	if !r.MatchString(resp) {
		t.Fatalf("\nExpected: \n%v\nGot: \n%v", expected, resp)
	}
}
