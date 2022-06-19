from django.conf.urls import include, patterns, url
from django.contrib import admin

admin.autodiscover()

from links.views import LinkDetailView, LinkListView

urlpatterns = patterns(
    "",
    # Examples:
    # url(r'^$', 'linkify.views.home', name='home'),
    # url(r'^blog/', include('blog.urls')),
    url(r"^admin/", include(admin.site.urls)),
    url(r"^links/(?P<pk>\d+)/$", LinkDetailView.as_view(), name="detail-link"),
    url(r"^links/$", LinkListView.as_view(), name="list-link"),
)
