  void _showBusChangeRequestModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _BusChangeRequestModal(
          currentRunId: _run['id'] ?? 0,
          serviceDate: _run['service_date'] ?? '',
          onSuccess: _refreshDetails,
        );
      },
    );
  }
