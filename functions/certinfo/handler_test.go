package function

import (
	"regexp"
	"testing"
)

func TestHandleReturnsCorrectResponse(t *testing.T) {
	expected := "Google Internet Authority"
	resp := Handle([]byte("www.google.com/about/"))

	r := regexp.MustCompile("(?m:" + expected + ")")
	if !r.MatchString(resp) {
		t.Fatalf("\nExpected: \n%v\nGot: \n%v", expected, resp)
	}
}
